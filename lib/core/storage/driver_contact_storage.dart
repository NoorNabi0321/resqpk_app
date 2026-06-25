import 'package:hive_flutter/hive_flutter.dart';

/// Caches the currently-assigned driver's contact in Hive so the patient can
/// still reach them (SMS/call) if the internet drops mid-emergency.
class DriverContactStorage {
  static const _boxName = 'driver_contact';

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<Map<String, String?>?> getActiveDriverContact() async {
    final box = await _box();
    final phone = box.get('active_driver_phone');
    if (phone == null) return null;
    return {
      'name': box.get('active_driver_name')?.toString(),
      'phone': phone.toString(),
      'vehicleNumber': box.get('active_vehicle_number')?.toString(),
      'caseId': box.get('active_case_id')?.toString(),
      'savedAt': box.get('saved_at')?.toString(),
    };
  }

  static Future<void> saveDriverContact({
    required String? name,
    required String? phone,
    required String? vehicleNumber,
    required String? caseId,
  }) async {
    if (phone == null || phone.isEmpty) return;
    final box = await _box();
    await box.put('active_driver_name', name ?? '');
    await box.put('active_driver_phone', phone);
    await box.put('active_vehicle_number', vehicleNumber ?? '');
    await box.put('active_case_id', caseId ?? '');
    await box.put('saved_at', DateTime.now().toIso8601String());
  }

  static Future<void> clearDriverContact() async {
    final box = await _box();
    await box.clear();
  }

  static bool hasActiveDriverContact(Map? contact) {
    return contact != null && contact['phone'] != null;
  }
}
