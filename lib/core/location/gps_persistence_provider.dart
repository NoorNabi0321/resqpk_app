import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gps_persistence_service.dart';

/// Singleton GPS persistence service. Start it after the patient logs in:
///   await ref.read(gpsPersistenceServiceProvider).initialize();
///   ref.read(gpsPersistenceServiceProvider).startPersisting();
final gpsPersistenceServiceProvider = Provider<GPSPersistenceService>((ref) {
  final service = GPSPersistenceService();
  ref.onDispose(service.dispose);
  return service;
});
