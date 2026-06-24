import 'package:flutter/foundation.dart';

/// Backend base URLs and endpoint paths.
class ApiConstants {
  ApiConstants._();

  // Dev backend. 10.0.2.2 is the host's localhost on the standard AVD emulator,
  // but LDPlayer needs the PC's LAN IP instead.
  // static const String baseUrl = 'http://10.0.2.2:3000'; // standard AVD
  static const String baseUrl = 'http://127.0.0.1:3000'; // via `adb reverse tcp:3000 tcp:3000`
  static const String productionUrl = 'https://resqpk-backend.onrender.com';

  /// Dev build → local backend; release build → Render.
  static String get currentBaseUrl => kReleaseMode ? productionUrl : baseUrl;

  // Auth endpoints
  static const String patientRegister = '/api/auth/patient/register';
  static const String driverRegister = '/api/auth/driver/register';
  static const String patientLogin = '/api/auth/patient/login';
  static const String driverLogin = '/api/auth/driver/login';
  static const String getMe = '/api/auth/me';
  static const String updateMedicalProfile = '/api/auth/medical-profile';
  static const String refreshToken = '/api/auth/refresh';
}
