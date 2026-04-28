import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/auth/controller/login_controller.dart';
import 'package:unii_app/services/auth_service.dart';
import '../helpers/fakes.dart';

void main() {
  late LoginController controller;
  late FakeAuthService fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthService();
    Get.put<AuthService>(fakeAuth);
    controller = Get.put(LoginController());
  });

  tearDown(() => Get.reset());

  test('empty phone sets errorMessage without calling service', () {
    controller.phoneController.text = '';
    controller.passwordController.text = 'password123';

    controller.login();

    expect(controller.errorMessage.value, '请输入手机号');
    expect(fakeAuth.loginCallCount, 0);
  });

  test('empty password sets errorMessage without calling service', () {
    controller.phoneController.text = '13800138001';
    controller.passwordController.text = '';

    controller.login();

    expect(controller.errorMessage.value, '请输入密码');
    expect(fakeAuth.loginCallCount, 0);
  });

  test('login failure sets errorMessage and clears isLoading', () async {
    fakeAuth.shouldLoginFail = true;
    controller.phoneController.text = '13800138001';
    controller.passwordController.text = 'wrongpassword';

    await controller.login();

    expect(controller.isLoading.value, false);
    expect(controller.errorMessage.value, isNotEmpty);
  });
}
