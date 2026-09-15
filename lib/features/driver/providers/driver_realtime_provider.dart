import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../services/driver_location_broadcaster.dart';

final driverLocationBroadcasterProvider = Provider<DriverLocationBroadcaster>((ref) {
  final locationService = ref.read(locationServiceProvider);
  final socketService = ref.read(socketServiceProvider);
  final broadcaster = DriverLocationBroadcaster(locationService, socketService);
  ref.onDispose(() => broadcaster.dispose());
  return broadcaster;
});

class DriverOnlineState {
  final bool isOnline;
  final bool isBroadcasting;
  final bool isLoading;
  final Position? currentPosition;
  final String? error;

  const DriverOnlineState({
    this.isOnline = false,
    this.isBroadcasting = false,
    this.isLoading = false,
    this.currentPosition,
    this.error,
  });

  DriverOnlineState copyWith({
    bool? isOnline,
    bool? isBroadcasting,
    bool? isLoading,
    Position? currentPosition,
    String? error,
    bool clearError = false,
  }) {
    return DriverOnlineState(
      isOnline: isOnline ?? this.isOnline,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isLoading: isLoading ?? this.isLoading,
      currentPosition: currentPosition ?? this.currentPosition,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DriverOnlineNotifier extends StateNotifier<DriverOnlineState> {
  final SocketService _socketService;
  final DriverLocationBroadcaster _broadcaster;
  final LocationService _locationService;

  StreamSubscription<bool>? _readySubscription;
  bool _wasReady = false;
  bool _restoring = false;

  DriverOnlineNotifier(this._socketService, this._broadcaster, this._locationService)
      : super(const DriverOnlineState()) {
    // The server marks a driver unavailable the moment their socket drops. The
    // socket reconnects by itself, but until go_online is sent again dispatch
    // skips this driver while the app still shows Online.
    _readySubscription = _socketService.readyStream.listen((ready) {
      final reconnected = ready && !_wasReady;
      _wasReady = ready;
      if (reconnected && state.isOnline) _restoreOnline();
    });
  }

  Future<void> _restoreOnline() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final position =
          _locationService.lastPosition ?? await _locationService.getCurrentPosition();
      if (position == null || !state.isOnline) return;
      final res = await _socketService.emitDriverGoOnline(
        position.latitude,
        position.longitude,
        position.heading,
      );
      if (res['success'] != true) {
        debugPrint('Re-sending go_online after reconnect failed: ${res['error']}');
      }
    } catch (e) {
      debugPrint('Re-sending go_online after reconnect failed: $e');
    } finally {
      _restoring = false;
    }
  }

  @override
  void dispose() {
    _readySubscription?.cancel();
    super.dispose();
  }

  Future<void> goOnline() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not get your location. Allow location permission, turn on '
              'Location in the emulator, and set a GPS position.',
        );
        return;
      }

      final res = await _socketService.emitDriverGoOnline(
        position.latitude,
        position.longitude,
        position.heading,
      );
      if (res['success'] != true) {
        state = state.copyWith(
          isLoading: false,
          error: res['error']?.toString() ?? 'Failed to go online',
        );
        return;
      }

      await _broadcaster.startBroadcasting();
      state = state.copyWith(
        isLoading: false,
        isOnline: true,
        isBroadcasting: true,
        currentPosition: position,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> goOffline() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _broadcaster.stopBroadcasting();
      await _socketService.emitDriverGoOffline();
      state = state.copyWith(isLoading: false, isOnline: false, isBroadcasting: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final driverOnlineProvider =
    StateNotifierProvider<DriverOnlineNotifier, DriverOnlineState>((ref) {
  return DriverOnlineNotifier(
    ref.read(socketServiceProvider),
    ref.read(driverLocationBroadcasterProvider),
    ref.read(locationServiceProvider),
  );
});
