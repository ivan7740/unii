import 'package:get/get.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'location_reporter_service.dart';
import '../models/user.dart';

class AuthService extends GetxService {
  final ApiService _api = Get.find<ApiService>();
  final StorageService _storage = Get.find<StorageService>();

  final Rx<User?> currentUser = Rx<User?>(null);
  bool get isLoggedIn => _storage.isLoggedIn;

  Future<AuthResponse> register({
    String? phone,
    String? email,
    required String nickname,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/register', data: {
      if (phone != null) 'phone': phone, // ignore: use_null_aware_elements
      if (email != null) 'email': email, // ignore: use_null_aware_elements
      'nickname': nickname,
      'password': password,
    });

    final authResp = AuthResponse.fromJson(response.data);
    _saveAuth(authResp);
    return authResp;
  }

  Future<AuthResponse> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      if (phone != null) 'phone': phone, // ignore: use_null_aware_elements
      if (email != null) 'email': email, // ignore: use_null_aware_elements
      'password': password,
    });

    final authResp = AuthResponse.fromJson(response.data);
    _saveAuth(authResp);
    return authResp;
  }

  Future<User?> fetchMe() async {
    try {
      final response = await _api.dio.get('/auth/me');
      final user = User.fromJson(response.data);
      currentUser.value = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  void logout() {
    Get.find<LocationReporterService>().stopReporting();
    _storage.clearAuth();
    currentUser.value = null;
    Get.offAllNamed('/login');
  }

  void _saveAuth(AuthResponse auth) {
    _storage.accessToken = auth.accessToken;
    _storage.refreshToken = auth.refreshToken;
    currentUser.value = auth.user;
  }
}
