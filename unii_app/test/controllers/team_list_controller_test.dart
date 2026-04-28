import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/team/controller/team_list_controller.dart';
import 'package:unii_app/services/storage_service.dart';
import 'package:unii_app/services/team_service.dart';
import '../helpers/fakes.dart';

void main() {
  late TeamListController controller;
  late FakeTeamService fakeTeam;

  setUp(() {
    fakeTeam = FakeTeamService();
    Get.put<TeamService>(fakeTeam);
    Get.put<StorageService>(FakeStorageService());
    controller = Get.put(TeamListController());
  });

  tearDown(() => Get.reset());

  test('loadTeams success populates teams list', () async {
    fakeTeam.teamsToReturn = [makeTeam(), makeTeam(id: 'team-2', name: '团队B')];

    await controller.loadTeams();

    expect(controller.teams.length, 2);
    expect(controller.isLoading.value, false);
    expect(controller.error.value, isNull);
  });

  test('loadTeams failure sets error and leaves teams empty', () async {
    fakeTeam.shouldGetTeamsFail = true;

    await controller.loadTeams();

    expect(controller.teams.isEmpty, true);
    expect(controller.isLoading.value, false);
    expect(controller.error.value, isNotNull);
  });

  test('calling loadTeams twice invokes getMyTeams at least twice', () async {
    fakeTeam.teamsToReturn = [makeTeam()];

    await controller.loadTeams();
    await controller.loadTeams();

    // onInit already calls loadTeams once, so total >= 2
    expect(fakeTeam.getMyTeamsCallCount, greaterThanOrEqualTo(2));
  });
}
