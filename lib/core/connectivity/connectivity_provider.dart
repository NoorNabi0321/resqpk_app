import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

/// `true` when the device has any network interface. Exposed as an async bool.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref
      .read(connectivityServiceProvider)
      .statusStream
      .map((status) => status != ConnectivityResult.none);
});

final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  return ref.read(connectivityServiceProvider).statusStream;
});
