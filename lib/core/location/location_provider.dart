import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

final locationAccessProvider = FutureProvider<LocationAccess>((ref) async {
  if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;

  final permission = await Geolocator.checkPermission();
  return switch (permission) {
    LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.blocked,
    _ => LocationAccess.denied,
  };
});
