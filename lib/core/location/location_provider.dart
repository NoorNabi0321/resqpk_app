import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_persistence_provider.dart';
import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final currentPositionStreamProvider = StreamProvider<Position>((ref) {
  return ref.read(locationServiceProvider).positionStream;
});

/// Why the app does or does not have a position — as something the UI can
/// watch, rather than each screen calling geolocator and guessing.
enum LocationAccess {
  granted,

  /// Refused this time; asking again is allowed and usually works.
  denied,

  /// Refused permanently — only the system settings screen can undo it.
  blocked,

  /// Permission is fine, but the phone's location switch is off.
  serviceOff,
}

/// Coordinates to work from, without ever hanging the screen.
///
/// Tries, in order: the fix already in memory, a fresh one, and the last one
/// this phone wrote to Hive. The timeout is the point — a list that cannot get
/// a position should say "nothing nearby" and let the user pull to refresh,
/// not shimmer until the app is killed.
Future<({double lat, double lng})?> resolvePosition(
  Ref ref, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final locationService = ref.read(locationServiceProvider);

  final known = locationService.lastPosition;
  if (known != null) return (lat: known.latitude, lng: known.longitude);

  final fresh = await locationService
      .getCurrentPosition()
      .timeout(timeout, onTimeout: () => null);
  if (fresh != null) return (lat: fresh.latitude, lng: fresh.longitude);

  final cached = ref.read(gpsPersistenceServiceProvider).getLastKnownLocation();
  final lat = (cached?['lat'] as num?)?.toDouble();
  final lng = (cached?['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  return (lat: lat, lng: lng);
}

final locationAccessProvider = FutureProvider<LocationAccess>((ref) async {
  if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;

  final permission = await Geolocator.checkPermission();
  return switch (permission) {
    LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.blocked,
    _ => LocationAccess.denied,
  };
});
