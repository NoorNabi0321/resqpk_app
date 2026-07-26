import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/location/gps_persistence_provider.dart';
import '../data/camps_repository.dart';
import '../data/models/camp_model.dart';

final campsRepositoryProvider = Provider<CampsRepository>((ref) => CampsRepository());

/// Nearby camps for the patient's current position. Falls back to the last
/// known GPS in Hive so the list still works right after a cold start, before
/// the first fix arrives.
final nearbyCampsProvider = FutureProvider<List<CampModel>>((ref) async {
  final locationService = ref.read(locationServiceProvider);

  double? lat;
  double? lng;

  final position = locationService.lastPosition ?? await locationService.getCurrentPosition();
  if (position != null) {
    lat = position.latitude;
    lng = position.longitude;
  } else {
    final cached = ref.read(gpsPersistenceServiceProvider).getLastKnownLocation();
    lat = (cached?['lat'] as num?)?.toDouble();
    lng = (cached?['lng'] as num?)?.toDouble();
  }

  if (lat == null || lng == null) return <CampModel>[];

  return ref.read(campsRepositoryProvider).getNearbyCamps(lat, lng);
});

/// True when the visible list came from the offline cache rather than the API.
final campsServingCacheProvider = FutureProvider<bool>((ref) async {
  // Depend on the list so this re-evaluates after each refresh.
  await ref.watch(nearbyCampsProvider.future);
  return ref.read(campsRepositoryProvider).isServingCache();
});

/// A single camp from the already-loaded nearby list (detail screen).
final campByIdProvider = Provider.family<CampModel?, String>((ref, id) {
  final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const <CampModel>[];
  for (final camp in camps) {
    if (camp.id == id) return camp;
  }
  return null;
});
