import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/location_reporter_service.dart';
import '../../../models/user.dart';
import '../../../utils/constants.dart';

class SettingsController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final StorageService _storage = Get.find<StorageService>();
  final LocationReporterService _reporter = Get.find<LocationReporterService>();

  Rx<User?> get currentUser => _auth.currentUser;

  // 位置更新频率
  final RxInt locationFrequency = AppConstants.frequencyStandard.obs;

  // 是否共享位置
  final RxBool shareLocation = true.obs;

  // 地图样式
  final RxString mapStyle = 'standard'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _auth.fetchMe();
  }

  void _loadSettings() {
    locationFrequency.value =
        _storage.read<int>(AppConstants.locationFrequencyKey) ??
            AppConstants.frequencyStandard;
    shareLocation.value =
        _storage.read<bool>(AppConstants.shareLocationKey) ?? true;
    mapStyle.value =
        _storage.read<String>(AppConstants.mapStyleKey) ?? 'standard';
  }

  Future<void> setLocationFrequency(int seconds) async {
    locationFrequency.value = seconds;
    await _storage.write(AppConstants.locationFrequencyKey, seconds);
    _reporter.updateFrequency();
  }

  Future<void> setShareLocation(bool value) async {
    shareLocation.value = value;
    await _storage.write(AppConstants.shareLocationKey, value);
  }

  Future<void> setMapStyle(String style) async {
    mapStyle.value = style;
    await _storage.write(AppConstants.mapStyleKey, style);
  }

  void logout() {
    _auth.logout();
  }
}
