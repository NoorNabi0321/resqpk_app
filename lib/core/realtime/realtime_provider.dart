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
  final role = authState.role;

  // Reconnect when the user changes, and also when the live socket is
  // authenticated as a different role: the backend binds handlers per role, so
  // a socket carried over from a previous session would silently ignore this
  // role's events (a driver's "go online" would just time out).
  final staleUser = socketService.connectedUserId != userId;
  final staleRole = socketService.isAuthenticated &&
      role != null &&
      socketService.connectedRole != null &&
      socketService.connectedRole != role;

  if (staleUser || staleRole) {
    socketService.disconnect();
    await socketService.connect(userId: userId);
  }
});

/// Live "socket is authenticated" flag for widgets. Watching
/// socketServiceProvider itself never rebuilds, because the service mutates its
/// fields in place rather than producing a new value.
final socketReadyProvider = StreamProvider<bool>((ref) {
  return ref.read(socketServiceProvider).readyStream;
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
