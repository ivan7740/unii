import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/auth/controller/login_controller.dart';
import 'package:unii_app/modules/auth/view/login_view.dart';
import 'package:unii_app/services/auth_service.dart';
import '../helpers/fakes.dart';

void main() {
  setUp(() {
    Get.put<AuthService>(FakeAuthService());
    Get.put(LoginController());
  });

  tearDown(() => Get.reset());

  testWidgets('LoginView renders without crash', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('UNII'), findsOneWidget);
  });

  testWidgets('LoginView has phone and password TextFields', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('tapping login with empty phone shows error message',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('请输入手机号'), findsOneWidget);
  });
}
