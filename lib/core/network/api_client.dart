import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'interceptors.dart';

/// Thin Dio wrapper used by all repositories.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.currentBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(LoggingInterceptor());
  }

  /// Exposed for features that need multipart/streaming (e.g. AI report upload).
  Dio get dio => _dio;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    String? caseToken,
  }) async {
    final res = await _dio.post(path, data: data, options: _options(caseToken));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? caseToken,
  }) async {
    final res = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: _options(caseToken),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    String? caseToken,
  }) async {
    final res = await _dio.put(path, data: data, options: _options(caseToken));
    return _asMap(res.data);
  }

  /// Sends a single case's token instead of the account token — how a patient
  /// with no account reads their own case.
  Options? _options(String? caseToken) {
    if (caseToken == null || caseToken.isEmpty) return null;
    return Options(
      headers: {'Authorization': 'Bearer $caseToken'},
      extra: const {'caseScoped': true},
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }
}

/// Global singleton used across the app.
final apiClient = ApiClient();
