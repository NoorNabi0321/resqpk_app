import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/driver_repository.dart';
import '../data/models/driver_history_model.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

/// This driver's runs and counts. Refreshed by invalidating it — the duty
/// screen does that when a case completes, so today's number is never stale.
final driverHistoryProvider = FutureProvider<DriverHistory>((ref) {
  return ref.read(driverRepositoryProvider).getHistory();
});
