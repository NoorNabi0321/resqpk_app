import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'socket_events.dart';

/// Where the live connection actually is.
///
/// "Connecting" and "cannot connect" used to look identical on screen, so a
/// driver whose socket never opened waited on a spinner that was never going
/// to resolve. These are the states worth telling someone apart.
enum SocketStatus { idle, connecting, connected, authenticated, failed }

/// Wraps the Socket.io client: connection lifecycle, typed emit helpers, and
/// broadcast streams that widgets/providers listen to.
class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  String? _activeCaseId;
  String? _connectedUserId; // whose token the current socket was opened with

  final StreamController<Map<String, dynamic>> _driverLocationController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _etaUpdateController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caseUpdateController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _aiReportController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get driverLocationStream => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get etaUpdateStream => _etaUpdateController.stream;
  Stream<Map<String, dynamic>> get caseUpdateStream => _caseUpdateController.stream;

  /// AI report lifecycle events, tagged with a normalized 'event' key:
  /// 'processing' | 'report_ready' | 'error'.
  Stream<Map<String, dynamic>> get aiReportStream => _aiReportController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  String? get connectedUserId => _connectedUserId;

  /// The role the server authenticated this socket as. The backend only binds
  /// role-specific handlers, so a socket left over from a previous session
  /// silently ignores this role's events.
  String? _connectedRole;
  String? get connectedRole => _connectedRole;

  /// Emits whenever authentication state flips. SocketService is a plain
  /// mutable object, so widgets cannot watch its fields directly — reading
  /// `isConnected` in build() captures the value once and never updates.
  final StreamController<bool> _readyController = StreamController<bool>.broadcast();

  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  SocketStatus _status = SocketStatus.idle;
  String? _lastError;

  SocketStatus get status => _status;

  /// Why the last attempt failed, in words a driver can act on.
  String? get lastError => _lastError;

  /// Current status first, then every change.
  Stream<SocketStatus> get statusStream async* {
    yield _status;
    yield* _statusController.stream;
  }

  void _setStatus(SocketStatus status, {String? error}) {
    _status = status;
    _lastError = error;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _fail(String reason) => _setStatus(SocketStatus.failed, error: reason);

  /// Current readiness first, then every change — so a late subscriber still
  /// starts from the right value.
  Stream<bool> get readyStream async* {
    yield _isAuthenticated;
    yield* _readyController.stream;
  }

  void _setReady(bool ready) {
    _isAuthenticated = ready;
    if (!_readyController.isClosed) _readyController.add(ready);
  }

  /// Completes when the server has authenticated this socket.
  Completer<void>? _readyCompleter;

  /// Waits until the socket is authenticated, so an emitWithAck has a handler
  /// to answer it. Without this, an action fired during the handshake — which
  /// on a cold-started server can take half a minute — silently times out.
  Future<bool> waitUntilReady({Duration timeout = const Duration(seconds: 20)}) async {
    if (_isAuthenticated) return true;
    final completer = _readyCompleter;
    if (completer == null) return false;
    try {
      await completer.future.timeout(timeout);
      return _isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  /// Connects as a signed-in user, or — for a patient with no account — with a
  /// case token, which authenticates the socket for exactly one case. The
  /// server places such a connection in that case's room and registers no role
  /// handlers for it.
  ///
  /// Never throws. A connection that cannot be made is reported through
  /// [statusStream] and [lastError] instead: this is watched by a provider, and
  /// a thrown exception there is swallowed into a provider error nobody reads —
  /// which is how a driver came to sit on "Connecting…" with no idea why.
  Future<void> connect({String? userId, String? caseToken}) async {
    String? token;
    try {
      token = caseToken ?? await SecureStorage.getToken();
    } catch (e) {
      // Secure storage can fail to read back after a reinstall (the Android
      // keystore entry no longer decrypts). Say so rather than hanging.
      _fail('Could not read your sign-in. Please sign in again.');
      debugPrint('Socket token read failed: $e');
      return;
    }

    if (token == null || token.isEmpty) {
      _fail('You are signed out. Please sign in again.');
      return;
    }

    _setStatus(SocketStatus.connecting);

    // Tear down any previous socket (e.g. after switching accounts) so we don't
    // keep a stale session authenticated as the wrong user/role.
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _setReady(false);
    _connectedUserId = userId;
    _readyCompleter = Completer<void>();

    _socket = io.io(
      ApiConstants.currentBaseUrl,
      io.OptionBuilder()
          // Polling is kept as a fallback: some mobile carriers and captive
          // networks block raw websocket upgrades, and websocket-only would
          // then never connect at all.
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          // A fresh manager every time. socket_io_client keeps a global cache
          // keyed by URL, and reconnecting after a dispose can otherwise hand
          // back a socket attached to a torn-down manager that never opens.
          .enableForceNew()
          .setAuth({'token': token})
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      _isConnected = true;
      _setStatus(SocketStatus.connected);
      debugPrint('Socket connected: ${socket.id}');
    });
    socket.on(SocketEvents.authenticated, (data) {
      // The server registers role handlers only after authenticating, so this
      // is the first moment an emitWithAck can actually be answered.
      _connectedRole = _asMap(data)['role']?.toString();
      _setStatus(SocketStatus.authenticated);
      _setReady(true);
      if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter!.complete();
      debugPrint('Socket authenticated as $_connectedRole: $data');
    });
    socket.on(SocketEvents.authError, (err) {
      _setReady(false);
      _fail('The server rejected this sign-in. Please sign in again.');
      debugPrint('Socket auth error: $err');
    });
    socket.onDisconnect((_) {
      _isConnected = false;
      _setReady(false);
      // Socket.io retries on its own; say "connecting" rather than "failed"
      // unless the attempts run out.
      if (_status != SocketStatus.failed) _setStatus(SocketStatus.connecting);
      // Socket.io reconnects on its own and re-authenticates; give callers a
      // fresh completer to wait on, otherwise waitUntilReady() would see the
      // old completed one and give up instantly mid-reconnect.
      if (_readyCompleter?.isCompleted ?? true) _readyCompleter = Completer<void>();
      debugPrint('Socket disconnected');
    });
    // The reason the connection could not be made, kept for the UI. Socket.io
    // keeps retrying underneath, so this is a status line rather than a
    // verdict — but it must be visible, because "no route to the server" and
    // "the server rejected you" need completely different actions.
    socket.onConnectError((err) {
      _setStatus(SocketStatus.connecting, error: _readableError(err));
      debugPrint('Socket connect error: $err');
    });
    socket.onConnectTimeout((_) {
      _setStatus(SocketStatus.connecting, error: 'The server did not answer in time.');
    });
    socket.onError((err) => debugPrint('Socket error: $err'));

    // Incoming driver location (patient/dashboard listening).
    socket.on(SocketEvents.driverLocationBroadcast, (data) {
      _driverLocationController.add(_asMap(data));
    });

    // ETA updates.
    socket.on(SocketEvents.etaUpdate, (data) {
      _etaUpdateController.add(_asMap(data));
    });

    // Case status changes, tagged with a normalized 'event' key.
    socket.on(SocketEvents.caseCreated, (d) => _emitCaseUpdate('case_created', d));
    socket.on(SocketEvents.driverAssigned, (d) => _emitCaseUpdate('driver_assigned', d));
    socket.on(SocketEvents.driverEnRoute, (d) => _emitCaseUpdate('en_route', d));
    socket.on(SocketEvents.driverArrived, (d) => _emitCaseUpdate('arrived', d));
    socket.on(SocketEvents.caseCompleted, (d) => _emitCaseUpdate('completed', d));
    socket.on(SocketEvents.caseCancelled, (d) => _emitCaseUpdate('cancelled', d));
    socket.on(SocketEvents.noDriverFound, (d) => _emitCaseUpdate('no_driver_found', d));
    socket.on(SocketEvents.hospitalChanged, (d) => _emitCaseUpdate('hospital_changed', d));

    // v2 hospital decisions — driver and patient both listen in the case room.
    socket.on(SocketEvents.caseAccepted, (d) => _emitCaseUpdate('hospital_accepted', d));
    socket.on(SocketEvents.caseRedirected, (d) => _emitCaseUpdate('hospital_redirected', d));
    socket.on(SocketEvents.quickMessage, (d) => _emitCaseUpdate('quick_message', d));

    // Ambulance handover.
    socket.on(SocketEvents.driverChanged, (d) => _emitCaseUpdate('driver_changed', d));
    socket.on(SocketEvents.handoffReleased, (d) => _emitCaseUpdate('handoff_released', d));

    // AI report lifecycle (Module 6).
    socket.on(SocketEvents.aiProcessing, (d) => _aiReportController.add({'event': 'processing', ..._asMap(d)}));
    socket.on(SocketEvents.aiReportReady, (d) => _aiReportController.add({'event': 'report_ready', ..._asMap(d)}));
    socket.on(SocketEvents.aiError, (d) => _aiReportController.add({'event': 'error', ..._asMap(d)}));
  }

  void _emitCaseUpdate(String event, dynamic data) {
    _caseUpdateController.add({'event': event, ..._asMap(data)});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'value': data};
  }

  /// Turns socket.io's error object into something a driver can act on.
  String _readableError(dynamic err) {
    final text = err is Map ? (err['message'] ?? err).toString() : err.toString();
    final lower = text.toLowerCase();
    if (lower.contains('token') || lower.contains('auth')) {
      return 'The server rejected this sign-in. Please sign in again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The server did not answer in time. It may be waking up.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('refused')) {
      return 'Cannot reach the server. Check your internet.';
    }
    return text.length > 90 ? '${text.substring(0, 90)}…' : text;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _connectedUserId = null;
    _connectedRole = null;
    _readyCompleter = null;
    _setReady(false);
    _setStatus(SocketStatus.idle);
  }

  // --- Driver emits ---------------------------------------------------------

  void emitDriverLocation(double lat, double lng, double heading, double speed, {String? caseId}) {
    if (!_isConnected) return;
    _socket?.emit(SocketEvents.driverLocationUpdate, {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      if (caseId != null) 'caseId': caseId,
    });
  }

  Future<Map<String, dynamic>> emitDriverGoOnline(double lat, double lng, double heading) async {
    final ready = await waitUntilReady();
    if (!ready) {
      return {
        'success': false,
        'error': 'Could not reach the server. Check your internet and try again.',
      };
    }

    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      SocketEvents.driverGoOnline,
      {'lat': lat, 'lng': lng, 'heading': heading},
      ack: (response) {
        if (!completer.isCompleted) completer.complete(_asMap(response));
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => {
        'success': false,
        'error': 'The server did not respond. Please try again.',
      },
    );
  }

  Future<void> emitDriverGoOffline() async {
    _socket?.emitWithAck(SocketEvents.driverGoOffline, {}, ack: (_) {});
  }

  /// Joins the case room so hospital decisions (accept / redirect / messages),
  /// which are broadcast per-case, reach this driver.
  Future<Map<String, dynamic>> driverJoinCase(String caseId) async {
    _activeCaseId = caseId;
    final ready = await waitUntilReady();
    if (!ready) return {'success': false, 'error': 'not_connected'};

    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      SocketEvents.driverJoinCase,
      {'caseId': caseId},
      ack: (response) {
        if (!completer.isCompleted) completer.complete(_asMap(response));
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'timeout'},
    );
  }

  void driverLeaveCase(String caseId) {
    _socket?.emit(SocketEvents.driverLeaveCase, {'caseId': caseId});
    _activeCaseId = null;
  }

  // --- Patient emits --------------------------------------------------------

  Future<Map<String, dynamic>> joinCaseRoom(String caseId) async {
    _activeCaseId = caseId;
    final ready = await waitUntilReady();
    if (!ready) return {'success': false, 'error': 'not_connected'};

    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      SocketEvents.patientJoinCase,
      {'caseId': caseId},
      ack: (response) {
        if (!completer.isCompleted) completer.complete(_asMap(response));
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'timeout'},
    );
  }

  void leaveCaseRoom(String caseId) {
    _socket?.emit(SocketEvents.patientLeaveCase, {'caseId': caseId});
    _activeCaseId = null;
  }

  void emitPatientLocation(double lat, double lng) {
    if (_activeCaseId == null) return;
    _socket?.emit(SocketEvents.patientLocationUpdate, {'lat': lat, 'lng': lng});
  }

  void dispose() {
    _driverLocationController.close();
    _etaUpdateController.close();
    _caseUpdateController.close();
    _aiReportController.close();
    disconnect();
    _socket?.dispose();
    _readyController.close();
    _statusController.close();
  }
}
