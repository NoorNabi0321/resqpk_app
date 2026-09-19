import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_store.dart';

/// What this device knows about a patient with no account.
class PatientSession {
  const PatientSession({
    this.reporterPhone,
    this.reporterName,
    this.caseId,
    this.caseToken,
    this.accessCode,
    this.caseNumber,
    this.loaded = false,
  });

  final String? reporterPhone;
  final String? reporterName;
  final String? caseId;
  final String? caseToken;
  final String? accessCode;
  final String? caseNumber;

  /// False until the Hive read finishes, so the UI does not flash a phone
  /// prompt at someone who already gave their number.
  final bool loaded;

  bool get hasActiveCase => (caseId?.isNotEmpty ?? false) && (caseToken?.isNotEmpty ?? false);
  bool get hasPhone => reporterPhone?.isNotEmpty ?? false;

  PatientSession copyWith({
    String? reporterPhone,
    String? reporterName,
    String? caseId,
    String? caseToken,
    String? accessCode,
    String? caseNumber,
    bool? loaded,
    bool clearCase = false,
  }) {
    return PatientSession(
      reporterPhone: reporterPhone ?? this.reporterPhone,
      reporterName: reporterName ?? this.reporterName,
      caseId: clearCase ? null : (caseId ?? this.caseId),
      caseToken: clearCase ? null : (caseToken ?? this.caseToken),
      accessCode: clearCase ? null : (accessCode ?? this.accessCode),
      caseNumber: clearCase ? null : (caseNumber ?? this.caseNumber),
      loaded: loaded ?? this.loaded,
    );
  }
}

class SessionNotifier extends StateNotifier<PatientSession> {
  SessionNotifier() : super(const PatientSession()) {
    _ready = _restore();
  }

  late final Future<void> _ready;

  /// Awaited by anything that must not act on an empty session — the splash
  /// screen decides where to send the user from what this holds.
  Future<void> ensureLoaded() => _ready;

  Future<void> _restore() async {
    final phone = await SessionStore.reporterPhone();
    final name = await SessionStore.reporterName();
    final active = await SessionStore.activeCase();

    state = PatientSession(
      reporterPhone: phone,
      reporterName: name,
      caseId: active?.caseId,
      caseToken: active?.caseToken,
      accessCode: active?.accessCode,
      caseNumber: active?.caseNumber,
      loaded: true,
    );
  }

  /// Asked once, on the first emergency, then never again.
  Future<void> saveReporter({required String phone, String? name}) async {
    await SessionStore.saveReporterPhone(phone);
    if (name != null && name.trim().isNotEmpty) {
      await SessionStore.saveReporterName(name);
    }
    state = state.copyWith(reporterPhone: phone.trim(), reporterName: name?.trim());
  }

  Future<void> startCase({
    required String caseId,
    required String caseToken,
    String? accessCode,
    String? caseNumber,
    String? trackingUrl,
  }) async {
    await SessionStore.saveActiveCase(
      caseId: caseId,
      caseToken: caseToken,
      accessCode: accessCode,
      caseNumber: caseNumber,
      trackingUrl: trackingUrl,
    );
    state = state.copyWith(
      caseId: caseId,
      caseToken: caseToken,
      accessCode: accessCode,
      caseNumber: caseNumber,
    );
  }

  /// The case is over — the request stays in history, the live token does not.
  Future<void> endCase() async {
    await SessionStore.clearActiveCase();
    state = state.copyWith(clearCase: true);
  }

  /// Adopt a case reached by typing its request code.
  Future<void> adoptCase({
    required String caseId,
    required String caseToken,
    String? accessCode,
    String? caseNumber,
  }) =>
      startCase(
        caseId: caseId,
        caseToken: caseToken,
        accessCode: accessCode,
        caseNumber: caseNumber,
      );
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, PatientSession>((ref) => SessionNotifier());

/// The token to send for one case, or null when the caller's own account token
/// already covers it. Written as a plain function so it works from a provider's
/// `Ref` and a widget's `WidgetRef` alike.
String? caseTokenFor(PatientSession session, {required bool signedIn, required String caseId}) {
  if (signedIn) return null;
  return session.caseId == caseId ? session.caseToken : null;
}

/// Requests raised on this device, most recent first.
final recentRequestsProvider = FutureProvider<List<Map<String, String>>>((ref) {
  // Rebuilds when a new case starts, so the list is never stale.
  ref.watch(sessionProvider.select((s) => s.caseId));
  return SessionStore.recentRequests();
});
