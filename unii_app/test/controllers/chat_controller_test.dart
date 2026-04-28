import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/message/controller/chat_controller.dart';
import 'package:unii_app/services/auth_service.dart';
import 'package:unii_app/services/message_cache_service.dart';
import 'package:unii_app/services/message_service.dart';
import 'package:unii_app/services/team_service.dart';
import 'package:unii_app/services/ws_service.dart';
import '../helpers/fakes.dart';

void main() {
  late ChatController controller;
  late FakeMessageService fakeMessage;

  setUp(() {
    fakeMessage = FakeMessageService();
    Get.put<MessageService>(fakeMessage);
    Get.put<WsService>(FakeWsService());
    Get.put<AuthService>(FakeAuthService());
    Get.put<MessageCacheService>(FakeMessageCacheService());
    Get.put<TeamService>(FakeTeamService());

    Get.routing.args = {'team_id': 'team-1', 'team_name': '测试团队'};
    controller = Get.put(ChatController());
  });

  tearDown(() => Get.reset());

  test('loadMessages populates messages list', () async {
    fakeMessage.messagesToReturn = [makeMessage(id: 1), makeMessage(id: 2)];

    await controller.loadMessages();

    expect(controller.messages.length, 2);
    expect(controller.isLoading.value, false);
  });

  test('filteredMembers filters by mentionQuery', () {
    controller.members.assignAll([
      makeTeamMember(nickname: 'Alice'),
      makeTeamMember(nickname: 'Bob'),
    ]);

    controller.mentionQuery.value = 'ali';

    final result = controller.filteredMembers;
    expect(result.length, 1);
    expect(result.first.nickname, 'Alice');
  });

  test('sendTextMessage clears textController and sends content', () async {
    controller.textController.text = 'Hello team!';

    controller.sendTextMessage();
    await Future.delayed(Duration.zero);

    expect(controller.textController.text, '');
    expect(fakeMessage.lastSentContent, 'Hello team!');
  });
}
