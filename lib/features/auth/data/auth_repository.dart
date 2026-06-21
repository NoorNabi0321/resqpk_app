import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'models/user_model.dart';
import 'models/medical_profile_model.dart';

class AuthRepository {
  // 1. Register patient
  Future<Map<String, dynamic>> registerPatient({
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    try {
      final res = await apiClient.post(ApiConstants.patientRegister, data: {
        'full_name': fullName,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final data = _data(res);
      // Registration returns a token; persist it so the immediate
      // medical-profile step is authenticated.
      await _persistSession(data);
      return data;
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 2. Register driver
  Future<Map<String, dynamic>> registerDriver({
    required String fullName,
    required String phone,
    required String password,
    required String vehicleNumber,
    required String licenseNumber,
    String organization = 'Private',
    String? email,
  }) async {
    try {
      final res = await apiClient.post(ApiConstants.driverRegister, data: {
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'vehicle_number': vehicleNumber,
        'license_number': licenseNumber,
        'organization': organization,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final data = _data(res);
      await _persistSession(data);
      return data;
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 3. Login patient
  Future<Map<String, dynamic>> loginPatient({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await apiClient.post(
        ApiConstants.patientLogin,
        data: {'phone': phone, 'password': password},
      );
      final data = _data(res);
      await _persistSession(data);
      return data;
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 4. Login driver
  Future<Map<String, dynamic>> loginDriver({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await apiClient.post(
        ApiConstants.driverLogin,
        data: {'phone': phone, 'password': password},
      );
      final data = _data(res);
      await _persistSession(data);
      return data;
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 5. Current profile
  Future<UserModel> getMyProfile() async {
    try {
      final res = await apiClient.get(ApiConstants.getMe);
      return UserModel.fromJson(_data(res));
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 6. Update medical profile
  Future<MedicalProfileModel> updateMedicalProfile(MedicalProfileModel profile) async {
    try {
      final res = await apiClient.put(
        ApiConstants.updateMedicalProfile,
        data: profile.toJson(),
      );
      return MedicalProfileModel.fromJson(_data(res));
    } catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // 7. Logout
  Future<void> logout() => SecureStorage.clearAll();

  // 8. Logged-in check (token present and not expired)
  Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  // 9. Stored role from cached user data
  Future<String?> getStoredRole() async {
    final userData = await SecureStorage.getUserData();
    if (userData == null) return null;
    try {
      final map = jsonDecode(userData) as Map<String, dynamic>;
      return map['role']?.toString();
    } catch (_) {
      return null;
    }
  }

  // --- helpers -------------------------------------------------------------

  // Unwraps the standard { success, message, data, ... } envelope.
  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is Map<String, dynamic>) return d;
    return res;
  }

  // Saves token + user JSON after a successful login.
  Future<void> _persistSession(Map<String, dynamic> data) async {
    if (data['token'] != null) {
      await SecureStorage.saveToken(data['token'].toString());
    }
    if (data['user'] != null) {
      await SecureStorage.saveUserData(jsonEncode(data['user']));
    }
  }

  // Pulls the backend's error out of a DioException, preferring field-level
  // validation messages so the user sees exactly what to fix.
  String _errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          return errors
              .map((x) => x is Map && x['message'] != null ? x['message'].toString() : x.toString())
              .join('\n');
        }
        if (data['message'] != null) return data['message'].toString();
      }
      return e.message ?? 'Network error';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
