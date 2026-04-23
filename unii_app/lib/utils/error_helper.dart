import 'package:dio/dio.dart';

class ErrorHelper {
  static String message(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.cancel:
          return '';
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络连接失败，请检查网络';
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode ?? 0;
          if (status >= 500) return '服务器错误，请稍后重试';
          final data = e.response?.data;
          final msg = data is Map ? data['message']?.toString() : null;
          return (msg != null && msg.isNotEmpty) ? msg : '请求失败';
        default:
          return '网络异常，请重试';
      }
    }
    return '未知错误，请重试';
  }
}
