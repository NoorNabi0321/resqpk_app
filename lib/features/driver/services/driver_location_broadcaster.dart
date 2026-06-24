import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_service.dart';
import '../../../core/realtime/socket_service.dart';

/// Bridges GPS (LocationService) and the socket (SocketService): while a driver
/// is online, streams their position to the backend every few seconds.
class DriverLocationBroadcaster {
  final LocationService _locationService;
  final SocketService _socketService;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _heartbeatTimer;
  String? _activeCaseId;
  bool _isBroadcasting = false;

  DriverLocationBroadcaster(this._locationService, this._socketService);

  bool get isBroadcasting => _isBroadcasting;

  Future<void> startBroadcasting({String? caseId}) async {
    _activeCaseId = caseId;
    if (_isBroadcasting) return;

    await _locationService.startTracking(intervalSeconds: 5, minDistanceMeters: 10);

    _locationSubscription = _locationService.positionStream.listen((position) {
      if (position.accuracy > 100) {
        debugPrint('Skipping low-accuracy location: ${position.accuracy}m');
        return;
      }
      _socketService.emitDriverLocation(
        position.latitude,
        position.longitude,
        position.heading,
        position.speed * 3.6, // m/s -> km/h
        caseId: _activeCaseId,
      );
    });

    // Heartbeat: ping every 30s even if stationary, so the backend knows we're
    // still active.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final last = _locationService.lastPosition;
      if (last != null) {
        _socketService.emitDriverLocation(
          last.latitude,
          last.longitude,
          last.heading,
          0,
          caseId: _activeCaseId,
        );
      }
    });

    _isBroadcasting = true;
  }

  void stopBroadcasting() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _locationService.stopTracking();
    _isBroadcasting = false;
    _activeCaseId = null;
  }

  void updateActiveCaseId(String? caseId) {
    _activeCaseId = caseId;
  }

  void dispose() {
    stopBroadcasting();
  }
}
