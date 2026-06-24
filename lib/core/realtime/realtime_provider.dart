import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'socket_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Connects/disconnects the socket as the auth state changes.
final socketConnectionProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider);
  final socketService = ref.read(socketServiceProvider);

  if (authState.isAuthenticated && !socketService.isConnected) {
    await socketService.connect();
  } else if (!authState.isAuthenticated && socketService.isConnected) {
    socketService.disconnect();
  }
});

final driverLocationStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.read(socketServiceProvider).driverLocationStream;
});

final etaStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.read(socketServiceProvider).etaUpdateStream;
});

final caseUpdateStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.read(socketServiceProvider).caseUpdateStream;
});
