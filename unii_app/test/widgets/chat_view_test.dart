import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/message/controller/chat_controller.dart';
import 'package:unii_app/modules/message/view/chat_view.dart';
import 'package:unii_app/services/auth_service.dart';
import 'package:unii_app/services/message_cache_service.dart';
import 'package:unii_app/services/message_service.dart';
import 'package:unii_app/services/team_service.dart';
import 'package:unii_app/services/ws_service.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeMessageService fakeMessage;

  setUp(() {
    fakeMessage = FakeMessageService();
    Get.put<MessageService>(fakeMessage);
    Get.put<WsService>(FakeWsService());
    Get.put<AuthService>(FakeAuthService());
    Get.put<MessageCacheService>(FakeMessageCacheService());
    Get.put<TeamService>(FakeTeamService());

    Get.routing.args = {'team_id': 'team-1', 'team_name': '测试团队'};
    Get.put(ChatController());
  });

  tearDown(() => Get.reset());

  testWidgets('ChatView renders without crash and shows input field',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(1));
  });

  testWidgets('entering text and tapping send clears input field',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField).last;
    await tester.enterText(textField, '出发了！');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // After send, the input TextField should be empty
    final inputWidget = tester.widget<TextField>(find.byType(TextField).last);
    expect(inputWidget.controller?.text ?? '', isEmpty);
  });
}
