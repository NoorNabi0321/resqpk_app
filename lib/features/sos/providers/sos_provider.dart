import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'session_provider.dart';
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

  /// v2 — the destination hospital's decision: 'awaiting_review' | 'accepted'.

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

/// Nothing left to track once a case reaches one of these.
const Set<String> _terminalStatuses = {'completed', 'cancelled'};

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class SOSNotifier extends StateNotifier<SOSState> {
  final SOSRepository _repo;
  final SocketService _socketService;
  final LocationService _locationService;
  final Ref _ref;

  Timer? _countdownTimer;
  Timer? _locationUpdateTimer;
  StreamSubscription<Map<String, dynamic>>? _caseSub;

  SOSNotifier(this._repo, this._socketService, this._locationService, this._ref)
      : super(const SOSState());

  /// How long the SOS button must be held.
  ///
  /// Was ten seconds, which is a very long time to hold a phone steady while
  /// someone is bleeding — and long enough that people let go early, thinking
  /// it had not worked. Three seconds is still deliberate enough to prevent
  /// pocket triggers, and matches what phones use for their own emergency SOS.
  static const int holdSeconds = 3;

  void startSOSCountdown() {
    if (state.isSosCountingDown) return;
    state = state.copyWith(
      isSosCountingDown: true,
      sosCountdownSeconds: holdSeconds,
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

  // Released before the hold completes → cancel.
  void cancelSOSCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      isSosCountingDown: false,
      sosCountdownSeconds: holdSeconds,
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

      // Someone in an emergency is never sent to a registration screen: the
      // request goes out with a callback number, and the case token that comes
      // back is what lets this device follow the ambulance.
      final signedIn = _ref.read(authProvider).isAuthenticated;
      final session = _ref.read(sessionProvider);

      final result = await _repo.triggerSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        reporterPhone: signedIn ? null : session.reporterPhone,
        reporterName: signedIn ? null : session.reporterName,
      );
      final created = result.emergencyCase;

      if (!signedIn && result.caseToken != null) {
        await _ref.read(sessionProvider.notifier).startCase(
              caseId: created.id,
              caseToken: result.caseToken!,
              accessCode: result.accessCode,
              caseNumber: created.caseNumber,
              trackingUrl: result.trackingUrl,
            );
        // The socket reconnects with the case token, and the server puts a
        // case-scoped connection straight into its own room — there is nothing
        // to join by hand.
        await _ref.read(socketConnectionProvider.future);
      } else {
        // Hospital decisions are broadcast to the case room only (driver
        // assignment also reaches the patient's personal room), so retry once if
        // the socket was still connecting when the SOS fired.
        var joined = await _socketService.joinCaseRoom(created.id);
        if (joined['success'] != true) {
          await Future<void>.delayed(const Duration(seconds: 2));
          joined = await _socketService.joinCaseRoom(created.id);
        }
      }
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
        case 'hospital_changed':
          state = state.copyWith(
            activeCase: state.activeCase?.copyWith(
              hospitalId: data['hospitalId']?.toString(),
              hospitalName: data['hospitalName']?.toString(),
              hospitalLat: _toD(data['hospitalLat']),
              hospitalLng: _toD(data['hospitalLng']),
            ),
          );
          break;
        // v2 — the assigned ambulance handed the case to another driver.
        case 'driver_changed':
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
            ),
          );
          break;
        case 'cancelled':
          _cleanup();
          _forgetAnonymousCase();
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
    Future.delayed(const Duration(seconds: 3), () {
      if (state.status == SOSStatus.completed) {
        final id = state.activeCaseId;
        if (id != null) _socketService.leaveCaseRoom(id);
        _cleanup();
        _forgetAnonymousCase();
        state = const SOSState();
      }
    });
  }

  /// Drops the live case token once the case is over. The request itself stays
  /// in this device's history, so the report can still be opened by its code.
  void _forgetAnonymousCase() {
    if (_ref.read(authProvider).isAuthenticated) return;
    if (!_ref.read(sessionProvider).hasActiveCase) return;
    _ref.read(sessionProvider.notifier).endCase();
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

  /// The stored token for this case, when it belongs to a patient with no
  /// account. Null for a signed-in user, whose own JWT already covers it.
  String? _caseTokenFor(String caseId) => caseTokenFor(
        _ref.read(sessionProvider),
        signedIn: _ref.read(authProvider).isAuthenticated,
        caseId: caseId,
      );

  /// Reaches a request by the code printed on screen or sent over WhatsApp —
  /// from a second phone, or after clearing the app's data. The token comes
  /// back fresh, so the code alone is enough.
  Future<({String caseId, String status})> openByAccessCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final found = await _repo.lookupByAccessCode(normalized);

    await _ref.read(sessionProvider.notifier).adoptCase(
          caseId: found.caseId,
          caseToken: found.caseToken,
          accessCode: normalized,
          caseNumber: found.caseNumber,
        );

    // A finished request keeps its token — that is what opens the report — but
    // there is nothing left to track.
    if (!_terminalStatuses.contains(found.status)) {
      _cleanup();
      state = const SOSState();
      await restoreFromSession();
    }
    return (caseId: found.caseId, status: found.status);
  }

  /// Picks the case saved on this device back up after a restart — a force-close
  /// during an emergency must not lose the ambulance on its way.
  Future<void> restoreFromSession() async {
    if (state.activeCaseId != null) return;
    await _ref.read(sessionProvider.notifier).ensureLoaded();
    final session = _ref.read(sessionProvider);
    if (!session.hasActiveCase) return;

    try {
      final activeCase = await _repo.getCaseDetails(
        session.caseId!,
        caseToken: session.caseToken,
      );
      if (_terminalStatuses.contains(activeCase.status)) {
        await _ref.read(sessionProvider.notifier).endCase();
        return;
      }
      await restoreActiveCase(activeCase);
    } catch (_) {
      // Offline, or the token has expired — the SOS button still works.
    }
  }

  /// Rehydrates state for a case that was already running when the app was
  /// last closed, so tracking resumes instead of starting from scratch.
  Future<void> restoreActiveCase(EmergencyCaseModel activeCase) async {
    final statusByName = {
      'pending': SOSStatus.searching,
      'searching': SOSStatus.searching,
      'driver_assigned': SOSStatus.driverAssigned,
      'arrived': SOSStatus.arrived,
      'en_route': SOSStatus.enRoute,
    };

    state = state.copyWith(
      activeCaseId: activeCase.id,
      activeCase: activeCase,
      status: statusByName[activeCase.status] ?? SOSStatus.searching,
      isLoading: false,
      clearError: true,
    );

    try {
      // A case-scoped socket is already in its room; only an account socket
      // has to ask to join.
      if (_caseTokenFor(activeCase.id) == null) {
        await _socketService.joinCaseRoom(activeCase.id);
      } else {
        await _ref.read(socketConnectionProvider.future);
      }
      _listenToSocketEvents();
      if (activeCase.driverId != null) _startPatientLocationUpdates();
    } catch (_) {
      // Offline restore still shows the case; live updates resume on reconnect.
    }
  }

  // Apply a hospital change locally (called right after PUT /cases/:id/hospital
  // so the UI updates even before the socket broadcast round-trips).
  void applyHospitalChange({String? id, String? name, double? lat, double? lng}) {
    if (state.activeCase == null) return;
    state = state.copyWith(
      activeCase: state.activeCase!.copyWith(
        hospitalId: id,
        hospitalName: name,
        hospitalLat: lat,
        hospitalLng: lng,
      ),
    );
  }

  /// Sends the emergency without the three-second hold. Used right after the
  /// callback-number sheet, where saving is itself the deliberate confirmation
  /// the hold exists to provide.
  Future<void> triggerNow() async {
    if (state.activeCaseId != null) return;
    _countdownTimer?.cancel();
    await _triggerSOS();
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
      await _repo.cancelSOS(id, reason: 'changed_mind', caseToken: _caseTokenFor(id));
    } catch (_) {
      // Cancel is best-effort from the client's side.
    }
    _socketService.leaveCaseRoom(id);
    _cleanup();
    _forgetAnonymousCase();
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
    ref,
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
