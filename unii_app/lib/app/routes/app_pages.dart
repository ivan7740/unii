import 'package:get/get.dart';
import '../../modules/auth/binding/auth_binding.dart';
import '../../modules/auth/view/login_view.dart';
import '../../modules/auth/view/register_view.dart';
import '../../modules/auth/view/splash_view.dart';
import '../../modules/home/home_view.dart';
import '../../modules/message/binding/message_binding.dart';
import '../../modules/message/view/chat_view.dart';
import '../../modules/settings/binding/settings_binding.dart';
import '../../modules/settings/view/profile_edit_view.dart';
import '../../modules/settings/view/location_settings_view.dart';
import '../../modules/settings/view/privacy_settings_view.dart';
import '../../modules/location/binding/track_binding.dart';
import '../../modules/location/view/track_view.dart';
import '../../modules/team/binding/team_binding.dart';
import '../../modules/team/view/team_detail_view.dart';
import '../../modules/team/view/create_team_view.dart';
import '../../modules/team/view/join_team_view.dart';

class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const teamDetail = '/team/detail';
  static const createTeam = '/team/create';
  static const joinTeam = '/team/join';
  static const chat = '/chat';
  static const track = '/track';
  static const profileEdit = '/settings/profile';
  static const locationSettings = '/settings/location';
  static const privacySettings = '/settings/privacy';
}

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
    ),
    GetPage(
      name: Routes.teamDetail,
      page: () => const TeamDetailView(),
      binding: TeamDetailBinding(),
    ),
    GetPage(
      name: Routes.createTeam,
      page: () => const CreateTeamView(),
      binding: CreateTeamBinding(),
    ),
    GetPage(
      name: Routes.joinTeam,
      page: () => const JoinTeamView(),
      binding: JoinTeamBinding(),
    ),
    GetPage(
      name: Routes.chat,
      page: () => const ChatView(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: Routes.track,
      page: () => const TrackView(),
      binding: TrackBinding(),
    ),
    GetPage(
      name: Routes.profileEdit,
      page: () => const ProfileEditView(),
      binding: ProfileEditBinding(),
    ),
    GetPage(
      name: Routes.locationSettings,
      page: () => const LocationSettingsView(),
    ),
    GetPage(
      name: Routes.privacySettings,
      page: () => const PrivacySettingsView(),
    ),
  ];
}
