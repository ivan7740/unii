import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/team/controller/team_list_controller.dart';
import 'package:unii_app/modules/team/view/team_list_view.dart';
import 'package:unii_app/services/storage_service.dart';
import 'package:unii_app/services/team_service.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeTeamService fakeTeam;

  setUp(() {
    fakeTeam = FakeTeamService();
    Get.put<TeamService>(fakeTeam);
    Get.put<StorageService>(FakeStorageService());
    Get.put(TeamListController());
  });

  tearDown(() => Get.reset());

  testWidgets('empty team list shows no-team hint text', (tester) async {
    fakeTeam.teamsToReturn = [];

    await tester.pumpWidget(const GetMaterialApp(home: TeamListView()));
    await tester.pumpAndSettle();

    expect(find.text('还没有加入任何团队'), findsOneWidget);
  });

  testWidgets('non-empty team list shows team name in card', (tester) async {
    fakeTeam.teamsToReturn = [makeTeam(name: '徒步队')];

    await tester.pumpWidget(const GetMaterialApp(home: TeamListView()));
    // Manually trigger a reload so the controller picks up the updated teamsToReturn
    Get.find<TeamListController>().loadTeams();
    await tester.pumpAndSettle();

    expect(find.text('徒步队'), findsOneWidget);
  });
}
