import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';

class RegisterController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final phoneController = TextEditingController();
  final nicknameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onClose() {
    phoneController.dispose();
    nicknameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> register() async {
    final phone = phoneController.text.trim();
    final nickname = nicknameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (phone.isEmpty) {
      errorMessage.value = '请输入手机号';
      return;
    }
    if (nickname.isEmpty) {
      errorMessage.value = '请输入昵称';
      return;
    }
    if (password.length < 6) {
      errorMessage.value = '密码至少6位';
      return;
    }
    if (password != confirmPassword) {
      errorMessage.value = '两次密码输入不一致';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _authService.register(
        phone: phone,
        nickname: nickname,
        password: password,
      );
      Get.offAllNamed('/home');
    } catch (e) {
      errorMessage.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode ?? 0;
      if (status == 409) return '该手机号已注册';
      if (status == 400) return '请检查输入信息';
      return ''; // 网络/服务器错误已由 ApiService 统一弹出 Snackbar
    }
    return '注册失败，请重试'; // 非网络异常（罕见），内联提示
  }
}
