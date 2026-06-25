import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/storage/driver_contact_storage.dart';
import '../../../core/realtime/socket_service.dart';
import '../data/sos_repository.dart';
import '../data/models/emergency_case_model.dart';
import '../data/models/eta_update_model.dart';

enum SOSStatus {
  idle,
  countingDown,
  searching,
  driverAssigned,
  enRoute,
  arrived,
  completed,
  cancelled,
  noDriverFound,
  error,
}

class SOSState {
  final String? activeCaseId;
  final EmergencyCaseModel? activeCase;
  final SOSStatus status;
  final bool isLoading;
  final String? error;
  final int sosCountdownSeconds;
  final bool isSosCountingDown;

  const SOSState({
    this.activeCaseId,
    this.activeCase,
    this.status = SOSStatus.idle,
    this.isLoading = false,
    this.error,
    this.sosCountdownSeconds = 10,
    this.isSosCountingDown = false,
  });

  SOSState copyWith({
    String? activeCaseId,
    EmergencyCaseModel? activeCase,
    SOSStatus? status,
    bool? isLoading,
    String? error,
    int? sosCountdownSeconds,
    bool? isSosCountingDown,
    bool clearError = false,
  }) {
    return SOSState(
      activeCaseId: activeCaseId ?? this.activeCaseId,
      activeCase: activeCase ?? this.activeCase,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sosCountdownSeconds: sosCountdownSeconds ?? this.sosCountdownSeconds,
      isSosCountingDown: isSosCountingDown ?? this.isSosCountingDown,
    );
  }
}

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class SOSNotifier extends StateNotifier<SOSState> {
  final SOSRepository _repo;
  final SocketService _socketService;
  final LocationService _locationService;

  Timer? _countdownTimer;
  Timer? _locationUpdateTimer;
  StreamSubscription<Map<String, dynamic>>? _caseSub;

  SOSNotifier(this._repo, this._socketService, this._locationService)
      : super(const SOSState());

  // Hold the SOS button: 10s countdown, then trigger.
  void startSOSCountdown() {
    if (state.isSosCountingDown) return;
    state = state.copyWith(
      isSosCountingDown: true,
      sosCountdownSeconds: 10,
      status: SOSStatus.countingDown,
      clearError: true,
    );
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.sosCountdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(sosCountdownSeconds: 0);
        _triggerSOS();
      } else {
        state = state.copyWith(sosCountdownSeconds: next);
      }
    });
  }

  // Released before 10s → cancel.
  void cancelSOSCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      isSosCountingDown: false,
      sosCountdownSeconds: 10,
      status: SOSStatus.idle,
    );
  }

  Future<void> _triggerSOS() async {
    state = state.copyWith(
      status: SOSStatus.searching,
      isLoading: true,
      isSosCountingDown: false,
      clearError: true,
    );
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        state = state.copyWith(
          status: SOSStatus.error,
          isLoading: false,
          error: 'Could not get your location',
        );
        return;
      }

      final created = await _repo.triggerSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      await _socketService.joinCaseRoom(created.id);
      _listenToSocketEvents();

      state = state.copyWith(
        activeCaseId: created.id,
        activeCase: created,
        status: SOSStatus.searching,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: SOSStatus.error,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _listenToSocketEvents() {
    _caseSub?.cancel();
    _caseSub = _socketService.caseUpdateStream.listen((data) {
      switch (data['event']?.toString()) {
        case 'driver_assigned':
          final driver = data['driver'] as Map<String, dynamic>?;
          state = state.copyWith(
            status: SOSStatus.driverAssigned,
            activeCase: state.activeCase?.copyWith(
              status: 'driver_assigned',
              driverId: driver?['id']?.toString(),
              driverName: driver?['fullName']?.toString(),
              driverPhone: driver?['phone']?.toString(),
              vehicleNumber: driver?['vehicleNumber']?.toString(),
              driverLat: _toD(driver?['currentLat']),
              driverLng: _toD(driver?['currentLng']),
              estimatedDriverArrivalSeconds: data['etaSeconds'] is int
                  ? data['etaSeconds']
                  : int.tryParse('${data['etaSeconds']}'),
              shareToken: data['shareToken']?.toString(),
              shareUrl: data['shareUrl']?.toString(),
            ),
          );
          // Cache driver contact locally so it survives an internet drop.
          DriverContactStorage.saveDriverContact(
            name: driver?['fullName']?.toString(),
            phone: driver?['phone']?.toString(),
            vehicleNumber: driver?['vehicleNumber']?.toString(),
            caseId: state.activeCase?.id,
          );
          _startPatientLocationUpdates();
          break;
        case 'en_route':
          state = state.copyWith(
            status: SOSStatus.enRoute,
            activeCase: state.activeCase?.copyWith(status: 'en_route'),
          );
          break;
        case 'arrived':
          state = state.copyWith(
            status: SOSStatus.arrived,
            activeCase: state.activeCase?.copyWith(status: 'arrived'),
          );
          break;
        case 'completed':
          state = state.copyWith(
            status: SOSStatus.completed,
            activeCase: state.activeCase?.copyWith(status: 'completed'),
          );
          _onCompleted();
          break;
        case 'no_driver_found':
          state = state.copyWith(status: SOSStatus.noDriverFound);
          break;
        case 'cancelled':
          DriverContactStorage.clearDriverContact();
          _cleanup();
          state = const SOSState(status: SOSStatus.cancelled);
          break;
        default:
          break;
      }
    });
  }

  void _startPatientLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null) _socketService.emitPatientLocation(pos.latitude, pos.longitude);
    });
  }

  void _onCompleted() {
    _locationUpdateTimer?.cancel();
    DriverContactStorage.clearDriverContact();
    Future.delayed(const Duration(seconds: 3), () {
      if (state.status == SOSStatus.completed) {
        final id = state.activeCaseId;
        if (id != null) _socketService.leaveCaseRoom(id);
        _cleanup();
        state = const SOSState();
      }
    });
  }

  // Update ETA from the eta:update stream (forwarded by etaListenerProvider).
  void updateETA(EtaUpdateModel eta) {
    if (state.activeCase == null) return;
    state = state.copyWith(
      activeCase: state.activeCase!.copyWith(
        estimatedDriverArrivalSeconds: eta.durationSeconds,
      ),
    );
  }

  // Re-trigger a fresh SOS (e.g. from the No Driver Found screen).
  Future<void> retry() async {
    _cleanup();
    state = const SOSState();
    await _triggerSOS();
  }

  // Clear local SOS state without calling the backend (case is already terminal).
  void reset() {
    _cleanup();
    state = const SOSState();
  }

  Future<void> cancelActiveCase() async {
    if (state.isSosCountingDown) {
      cancelSOSCountdown();
      return;
    }
    final id = state.activeCaseId;
    if (id == null) return;
    try {
      await _repo.cancelSOS(id, reason: 'changed_mind');
    } catch (_) {
      // Cancel is best-effort from the client's side.
    }
    _socketService.leaveCaseRoom(id);
    _cleanup();
    state = const SOSState();
  }

  void _cleanup() {
    _countdownTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _caseSub?.cancel();
    _caseSub = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final sosRepositoryProvider = Provider<SOSRepository>((ref) => SOSRepository());

final sosProvider = StateNotifierProvider<SOSNotifier, SOSState>((ref) {
  return SOSNotifier(
    ref.read(sosRepositoryProvider),
    ref.read(socketServiceProvider),
    ref.read(locationServiceProvider),
  );
});

// Watch this to forward eta:update socket events into the SOS state.
final etaListenerProvider = Provider<void>((ref) {
  ref.listen(etaStreamProvider, (_, next) {
    next.whenData((data) {
      ref.read(sosProvider.notifier).updateETA(EtaUpdateModel.fromJson(data));
    });
  });
});
