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

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.post(path, data: data);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await _dio.get(path);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.put(path, data: data);
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }
}

/// Global singleton used across the app.
final apiClient = ApiClient();
