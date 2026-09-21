import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../data/camps_repository.dart';
import '../data/models/camp_model.dart';

final campsRepositoryProvider = Provider<CampsRepository>((ref) => CampsRepository());

/// Nearby camps for the patient's current position. Falls back to the last
/// known GPS in Hive so the list still works right after a cold start, before
/// the first fix arrives.
final nearbyCampsProvider = FutureProvider<List<CampModel>>((ref) async {
  final position = await resolvePosition(ref);
  if (position == null) return <CampModel>[];
  return ref.read(campsRepositoryProvider).getNearbyCamps(position.lat, position.lng);
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
