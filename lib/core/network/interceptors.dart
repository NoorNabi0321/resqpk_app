import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';

/// Attaches the Bearer token to every request; clears it on a 401.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // A case-scoped call carries its own token (a patient with no account has
    // nothing else), so never overwrite one the caller set.
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }

    final token = await SecureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // An expired case token says nothing about the signed-in user's session.
    final caseScoped = err.requestOptions.extra['caseScoped'] == true;
    if (err.response?.statusCode == 401 && !caseScoped) {
      // Token is invalid/expired. Clear it; the router's auth guard (D6) will
      // redirect to the login flow on the next navigation.
      await SecureStorage.deleteToken();
    }
    handler.next(err);
  }
}

/// Logs request/response in debug builds only.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) debugPrint('--> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<-- ERROR ${err.response?.statusCode} ${err.requestOptions.uri}');
    }
    handler.next(err);
  }
}
