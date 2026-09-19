import 'package:hive_flutter/hive_flutter.dart';

/// What the device remembers about a patient who has no account.
///
/// Registration is not asked for in an emergency, so the case token returned by
/// the server is the only credential this person holds. It lives here, with the
/// request code and the callback number, so a force-close does not lose the
/// ambulance they are waiting for.
///
/// Hive rather than secure storage on purpose: these are short-lived, single-
/// case capabilities, and secure storage is slow enough to notice on a cold
/// start. An account's JWT still goes to SecureStorage.
class SessionStore {
  SessionStore._();

  static const _boxName = 'resqpk_session';

  // Tokens are issued for 24 hours; anything older only produces confusing 401s.
  static const Duration _tokenLife = Duration(hours: 24);
  static const int _maxRemembered = 5;

  static Future<Box> _box() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);

  // --- the callback number, asked once rather than every emergency ---------

  static Future<String?> reporterPhone() async {
    final box = await _box();
    final value = box.get('reporter_phone')?.toString();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> saveReporterPhone(String phone) async {
    final box = await _box();
    await box.put('reporter_phone', phone.trim());
  }

  static Future<String?> reporterName() async {
    final box = await _box();
    final value = box.get('reporter_name')?.toString();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> saveReporterName(String name) async {
    final box = await _box();
    await box.put('reporter_name', name.trim());
  }

  // --- the case currently running ------------------------------------------

  static Future<void> saveActiveCase({
    required String caseId,
    required String caseToken,
    String? accessCode,
    String? caseNumber,
    String? trackingUrl,
  }) async {
    final box = await _box();
    final savedAt = DateTime.now().toIso8601String();
    await box.putAll({
      'active_case_id': caseId,
      'active_case_token': caseToken,
      'active_access_code': accessCode ?? '',
      'active_case_number': caseNumber ?? '',
      'active_saved_at': savedAt,
    });
    await rememberRequest(
      caseId: caseId,
      accessCode: accessCode,
      caseNumber: caseNumber,
      trackingUrl: trackingUrl,
      savedAt: savedAt,
    );
  }

  /// The live case, or null when there is none or its token has expired.
  static Future<({String caseId, String caseToken, String? accessCode, String? caseNumber})?>
      activeCase() async {
    final box = await _box();
    final id = box.get('active_case_id')?.toString();
    final token = box.get('active_case_token')?.toString();
    final savedAt = DateTime.tryParse(box.get('active_saved_at')?.toString() ?? '');

    if (id == null || id.isEmpty || token == null || token.isEmpty) return null;
    if (savedAt == null || DateTime.now().difference(savedAt) > _tokenLife) {
      await clearActiveCase();
      return null;
    }

    final code = box.get('active_access_code')?.toString();
    final number = box.get('active_case_number')?.toString();
    return (
      caseId: id,
      caseToken: token,
      accessCode: (code == null || code.isEmpty) ? null : code,
      caseNumber: (number == null || number.isEmpty) ? null : number,
    );
  }

  static Future<void> clearActiveCase() async {
    final box = await _box();
    await box.deleteAll([
      'active_case_id',
      'active_case_token',
      'active_access_code',
      'active_case_number',
      'active_saved_at',
    ]);
  }

  // --- history on this device ----------------------------------------------

  static Future<void> rememberRequest({
    required String caseId,
    String? accessCode,
    String? caseNumber,
    String? trackingUrl,
    String? savedAt,
  }) async {
    final box = await _box();
    final existing = await recentRequests();
    final entry = {
      'caseId': caseId,
      'accessCode': accessCode ?? '',
      'caseNumber': caseNumber ?? '',
      'trackingUrl': trackingUrl ?? '',
      'savedAt': savedAt ?? DateTime.now().toIso8601String(),
    };
    final merged = [entry, ...existing.where((e) => e['caseId'] != caseId)];
    await box.put('recent_requests', merged.take(_maxRemembered).toList());
  }

  /// Most recent first. Entries older than a day are dropped: their tokens have
  /// expired, and showing a request that cannot be opened is worse than none.
  static Future<List<Map<String, String>>> recentRequests() async {
    final box = await _box();
    final raw = box.get('recent_requests');
    if (raw is! List) return [];

    final cutoff = DateTime.now().subtract(_tokenLife);
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
        .where((e) {
          final at = DateTime.tryParse(e['savedAt'] ?? '');
          return at != null && at.isAfter(cutoff);
        })
        .toList();
  }

  static Future<void> forget(String caseId) async {
    final box = await _box();
    final remaining = (await recentRequests()).where((e) => e['caseId'] != caseId).toList();
    await box.put('recent_requests', remaining);
  }
}
