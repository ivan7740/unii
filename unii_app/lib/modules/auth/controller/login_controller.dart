import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';

class LoginController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> login() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (phone.isEmpty) {
      errorMessage.value = '请输入手机号';
      return;
    }
    if (password.isEmpty) {
      errorMessage.value = '请输入密码';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _authService.login(phone: phone, password: password);
      Get.offAllNamed('/home');
    } catch (e) {
      errorMessage.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
  }

  void goToRegister() {
    Get.toNamed('/register');
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401) return '手机号或密码错误';
      return ''; // 网络/服务器错误已由 ApiService 统一弹出 Snackbar
    }
    return '登录失败，请重试'; // 非网络异常（罕见），内联提示
  }
}
