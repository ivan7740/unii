import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/theme/app_theme.dart';
import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/team_service.dart';
import 'services/location_service.dart';
import 'services/message_service.dart';
import 'services/ws_service.dart';
import 'services/location_reporter_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化全局服务
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => ApiService().init());
  Get.put(AuthService());
  Get.put(TeamService());
  Get.put(LocationService());
  Get.put(MessageService());
  Get.put(WsService());
  Get.put(LocationReporterService());

  runApp(const UniiApp());
}

class UniiApp extends StatelessWidget {
  const UniiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialBinding: InitialBinding(),
      initialRoute: Routes.splash,
      getPages: AppPages.pages,
    );
  }
}
