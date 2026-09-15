import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'socket_events.dart';

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

  Future<void> connect({String? userId}) async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }

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
          .setAuth({'token': token})
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected: ${socket.id}');
    });
    socket.on(SocketEvents.authenticated, (data) {
      // The server registers role handlers only after authenticating, so this
      // is the first moment an emitWithAck can actually be answered.
      _connectedRole = _asMap(data)['role']?.toString();
      _setReady(true);
      if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter!.complete();
      debugPrint('Socket authenticated as $_connectedRole: $data');
    });
    socket.on(SocketEvents.authError, (err) {
      _setReady(false);
      debugPrint('Socket auth error: $err');
    });
    socket.onDisconnect((_) {
      _isConnected = false;
      _setReady(false);
      // Socket.io reconnects on its own and re-authenticates; give callers a
      // fresh completer to wait on, otherwise waitUntilReady() would see the
      // old completed one and give up instantly mid-reconnect.
      if (_readyCompleter?.isCompleted ?? true) _readyCompleter = Completer<void>();
      debugPrint('Socket disconnected');
    });
    socket.onConnectError((err) => debugPrint('Socket connect error: $err'));

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

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _connectedUserId = null;
    _connectedRole = null;
    _readyCompleter = null;
    _setReady(false);
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
  }
}
