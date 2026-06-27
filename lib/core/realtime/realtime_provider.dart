import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'socket_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Connects/disconnects the socket as the auth state changes. Reconnects when
/// the logged-in user changes (e.g. patient → driver) so the socket always
/// carries the current user's token/role, not a lingering previous session.
final socketConnectionProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider);
  final socketService = ref.read(socketServiceProvider);

  if (!authState.isAuthenticated) {
    socketService.disconnect();
    return;
  }

  final userId = authState.user?.id;
  if (socketService.connectedUserId != userId) {
    socketService.disconnect();
    await socketService.connect(userId: userId);
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
