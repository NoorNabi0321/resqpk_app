import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores the JWT and cached user data.
class SecureStorage {
  SecureStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  static Future<void> saveUserData(String jsonString) =>
      _storage.write(key: _userKey, value: jsonString);

  static Future<String?> getUserData() => _storage.read(key: _userKey);

  static Future<void> clearAll() => _storage.deleteAll();
}
