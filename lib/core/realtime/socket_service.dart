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

  final StreamController<Map<String, dynamic>> _driverLocationController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _etaUpdateController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caseUpdateController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get driverLocationStream => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get etaUpdateStream => _etaUpdateController.stream;
  Stream<Map<String, dynamic>> get caseUpdateStream => _caseUpdateController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> connect() async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }

    _socket = io.io(
      ApiConstants.currentBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected: ${socket.id}');
    });
    socket.on(SocketEvents.authenticated, (data) {
      _isAuthenticated = true;
      debugPrint('Socket authenticated: $data');
    });
    socket.on(SocketEvents.authError, (err) {
      _isAuthenticated = false;
      debugPrint('Socket auth error: $err');
    });
    socket.onDisconnect((_) {
      _isConnected = false;
      _isAuthenticated = false;
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
  }

  void _emitCaseUpdate(String event, dynamic data) {
    _caseUpdateController.add({'event': event, ..._asMap(data)});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'value': data};
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
    _isAuthenticated = false;
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
    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      SocketEvents.driverGoOnline,
      {'lat': lat, 'lng': lng, 'heading': heading},
      ack: (response) {
        if (!completer.isCompleted) completer.complete(_asMap(response));
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'timeout'},
    );
  }

  Future<void> emitDriverGoOffline() async {
    _socket?.emitWithAck(SocketEvents.driverGoOffline, {}, ack: (_) {});
  }

  // --- Patient emits --------------------------------------------------------

  Future<Map<String, dynamic>> joinCaseRoom(String caseId) async {
    _activeCaseId = caseId;
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
    disconnect();
    _socket?.dispose();
  }
}
