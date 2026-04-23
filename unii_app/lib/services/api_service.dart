import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import '../utils/constants.dart';
import '../utils/error_helper.dart';
import 'storage_service.dart';

class ApiService extends GetxService {
  late Dio dio;
  final StorageService _storage = Get.find<StorageService>();

  Future<ApiService> init() async {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));

    return this;
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      final isAuthEndpoint = path.contains('/auth/login') ||
          path.contains('/auth/register');

      if (!isAuthEndpoint) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
          try {
            final response = await dio.fetch(opts);
            return handler.resolve(response);
          } on DioException catch (e) {
            return handler.next(e);
          }
        } else {
          _storage.clearAuth();
          Get.offAllNamed('/login');
        }
      }
      // Auth endpoints: let controller handle 401 inline (wrong credentials etc.)
    } else {
      final msg = ErrorHelper.message(err);
      if (msg.isNotEmpty) {
        Get.snackbar(
          '提示',
          msg,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(8),
        );
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
      )).post('/auth/refresh', data: {'refresh_token': refreshToken});

      if (response.statusCode == 200) {
        _storage.accessToken = response.data['access_token'];
        if (response.data['refresh_token'] != null) {
          _storage.refreshToken = response.data['refresh_token'];
        }
        return true;
      }
    } catch (_) {}
    return false;
  }
}
