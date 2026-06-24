import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// Debug testing aid: emulators (e.g. LDPlayer) default their mock GPS to the US,
// which the backend rejects (Pakistan-only). In DEBUG builds, if the device
// reports a location outside Pakistan, substitute a Hyderabad test position so
// the real-time features can be exercised. Release builds always use real GPS.
bool _inPakistan(double lat, double lng) =>
    lat >= 23.0 && lat <= 37.5 && lng >= 60.0 && lng <= 77.5;

Position _hyderabadTestPosition() => Position(
      latitude: 25.3792,
      longitude: 68.3683,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: true,
    );

Position _normalize(Position position) {
  if (kDebugMode && !_inPakistan(position.latitude, position.longitude)) {
    return _hyderabadTestPosition();
  }
  return position;
}

/// Wraps geolocator: permissions, a position stream for live tracking, and
/// accuracy helpers used by the driver/SOS screens.
class LocationService {
  final StreamController<Position> _positionController = StreamController.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;

  Stream<Position> get positionStream => _positionController.stream;
  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  Future<bool> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    // Ensure permission is granted first (this triggers the runtime dialog).
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      final position = _normalize(await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ));
      _lastPosition = position;
      return position;
    } catch (_) {
      // Couldn't get a fresh fix — fall back to the OS's last-known position.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) _lastPosition = _normalize(lastKnown);
      return _lastPosition;
    }
  }

  Future<void> startTracking({int intervalSeconds = 5, double minDistanceMeters = 10}) async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) throw Exception('Location permission denied');

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: minDistanceMeters.toInt(),
      intervalDuration: Duration(seconds: intervalSeconds),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'ResQPK is tracking your location for emergency response',
        notificationTitle: 'ResQPK Active',
        enableWakeLock: true,
      ),
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((raw) {
      final position = _normalize(raw);
      _lastPosition = position;
      _positionController.add(position);
    });

    _isTracking = true;
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  /// 0.0 (unusable) .. 1.0 (excellent) based on reported accuracy in meters.
  double getAccuracyLevel(Position position) {
    if (position.accuracy <= 10) return 1.0;
    if (position.accuracy <= 30) return 0.75;
    if (position.accuracy <= 60) return 0.5;
    if (position.accuracy <= 100) return 0.25;
    return 0.0;
  }

  String getAccuracyLabel(Position position) {
    final level = getAccuracyLevel(position);
    if (level >= 1.0) return 'Excellent';
    if (level >= 0.75) return 'Good';
    if (level >= 0.5) return 'Moderate';
    if (level >= 0.25) return 'Poor';
    return 'Very Poor — move to open area';
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
