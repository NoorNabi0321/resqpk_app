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

  /// In-flight requests, shared between callers.
  ///
  /// The home screen opens five location-dependent things at once — the
  /// location strip, the map, the hospital list, the camps list and the
  /// background GPS writer. Android only shows one permission dialog, and
  /// geolocator does not reliably answer the duplicate requests queued behind
  /// it: they can sit unresolved for the life of the screen. That is what left
  /// "Emergency hospitals" and "Free medical camps" shimmering forever while
  /// the map above them showed the user's position perfectly well.
  ///
  /// One request, one answer, handed to everyone who asked.
  Future<bool>? _pendingPermission;
  Future<Position?>? _pendingPosition;

  Future<bool> requestPermissions() {
    final pending = _pendingPermission;
    if (pending != null) return pending;

    final request = _requestPermissionsOnce();
    _pendingPermission = request;
    request.whenComplete(() {
      if (identical(_pendingPermission, request)) _pendingPermission = null;
    });
    return request;
  }

  Future<bool> _requestPermissionsOnce() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return false;
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      // A request already in progress elsewhere, or a platform error. Treat it
      // as "not now" rather than letting it propagate into a hung provider.
      debugPrint('Location permission request failed: $e');
      return false;
    }
  }

  Future<Position?> getCurrentPosition() {
    final pending = _pendingPosition;
    if (pending != null) return pending;

    final request = _getCurrentPositionOnce();
    _pendingPosition = request;
    request.whenComplete(() {
      if (identical(_pendingPosition, request)) _pendingPosition = null;
    });
    return request;
  }

  Future<Position?> _getCurrentPositionOnce() async {
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
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) _lastPosition = _normalize(lastKnown);
      } catch (_) {
        // Nothing to fall back to; callers handle a null position.
      }
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
