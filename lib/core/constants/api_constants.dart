import 'package:flutter/foundation.dart';

/// Backend base URLs and endpoint paths.
class ApiConstants {
  ApiConstants._();

  // Dev backend. 10.0.2.2 is the host's localhost on the standard AVD emulator,
  // but LDPlayer needs the PC's LAN IP instead.
  // static const String baseUrl = 'http://10.0.2.2:3000'; // standard AVD
  static const String baseUrl = 'http://127.0.0.1:3000'; // via `adb reverse tcp:3000 tcp:3000`
  static const String productionUrl = 'https://resqpk-backend.onrender.com';

  /// Set at build time to point any build at a specific backend:
  ///   flutter build apk --dart-define=RESQPK_API=https://resqpk-backend.onrender.com
  ///
  /// Without it a debug build talks to 127.0.0.1, which on a phone is the phone
  /// itself — the cause of "connection refused" when a debug APK is installed
  /// on a real device rather than run through `adb reverse`.
  static const String _apiOverride = String.fromEnvironment('RESQPK_API');

  /// Override if given, else release → Render, debug → local backend.
  static String get currentBaseUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    return kReleaseMode ? productionUrl : baseUrl;
  }

  // Auth endpoints
  static const String patientRegister = '/api/auth/patient/register';
  static const String driverRegister = '/api/auth/driver/register';
  static const String patientLogin = '/api/auth/patient/login';
  static const String driverLogin = '/api/auth/driver/login';
  static const String getMe = '/api/auth/me';
  static const String updateMedicalProfile = '/api/auth/medical-profile';
  static const String refreshToken = '/api/auth/refresh';
}
