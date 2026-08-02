import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/location/location_provider.dart';
import '../../sos/data/sos_repository.dart';

/// Nearby emergency-capable hospitals for the home screen list.
final nearbyHospitalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final position = locationService.lastPosition ?? await locationService.getCurrentPosition();
  if (position == null) return [];
  return SOSRepository().getNearbyHospitals(position.latitude, position.longitude);
});

/// Human-readable address for the location banner ("Bohri Bazar, Hyderabad").
/// Falls back to coordinates when reverse geocoding is unavailable offline.
final currentAddressProvider = FutureProvider<String>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final position = locationService.lastPosition ?? await locationService.getCurrentPosition();
  if (position == null) return 'Locating…';

  try {
    final marks = await placemarkFromCoordinates(position.latitude, position.longitude);
    if (marks.isEmpty) throw Exception('no placemark');
    final p = marks.first;
    final parts = [
      p.subLocality?.isNotEmpty == true ? p.subLocality : p.thoroughfare,
      p.locality,
      p.administrativeArea,
    ].where((s) => s != null && s.trim().isNotEmpty).toSet().toList();
    if (parts.isEmpty) throw Exception('empty placemark');
    return parts.join(', ');
  } catch (_) {
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }
});
