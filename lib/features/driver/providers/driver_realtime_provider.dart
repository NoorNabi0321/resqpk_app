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

  /// Whether dispatch can actually offer this driver a case.
  ///
  /// Not the same as [isOnline], and that gap is the whole point. The server
  /// refuses availability while a driver still holds an unfinished case, so a
  /// driver could sit on an "On duty" screen, connected and broadcasting, and
  /// be invisible to every dispatch ring. The app believed success:true meant
  /// on duty and never asked.
  final bool isAvailable;

  /// The case number keeping this driver out of dispatch, when there is one.
  final String? heldCaseNumber;

  const DriverOnlineState({
    this.isOnline = false,
    this.isBroadcasting = false,
    this.isLoading = false,
    this.isAvailable = false,
    this.currentPosition,
    this.error,
    this.heldCaseNumber,
  });

  /// On duty, but dispatch cannot reach them — worth saying out loud.
  bool get isOnlineButUnreachable => isOnline && !isAvailable;

  DriverOnlineState copyWith({
    bool? isOnline,
    bool? isBroadcasting,
    bool? isLoading,
    bool? isAvailable,
    Position? currentPosition,
    String? error,
    String? heldCaseNumber,
    bool clearError = false,
    bool clearHeldCase = false,
  }) {
    return DriverOnlineState(
      isOnline: isOnline ?? this.isOnline,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isLoading: isLoading ?? this.isLoading,
      isAvailable: isAvailable ?? this.isAvailable,
      currentPosition: currentPosition ?? this.currentPosition,
      error: clearError ? null : (error ?? this.error),
      heldCaseNumber: clearHeldCase ? null : (heldCaseNumber ?? this.heldCaseNumber),
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

      // Older builds of the server answer with success alone. Treating a
      // missing field as available keeps this working against them, rather
      // than showing every driver as unreachable.
      final available = res['isAvailable'] != false;
      final held = res['heldCase'] as Map?;

      state = state.copyWith(
        isLoading: false,
        isOnline: true,
        isBroadcasting: true,
        isAvailable: available,
        currentPosition: position,
        heldCaseNumber: held?['caseNumber']?.toString(),
        clearHeldCase: available,
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
      state = state.copyWith(
        isLoading: false,
        isOnline: false,
        isBroadcasting: false,
        isAvailable: false,
        clearHeldCase: true,
      );
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
