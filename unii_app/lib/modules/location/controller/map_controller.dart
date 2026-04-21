import 'dart:async';
import 'package:get/get.dart';
import '../../../models/location.dart';
import '../../../services/location_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/ws_service.dart';
import '../../../services/location_reporter_service.dart';
import '../../../utils/constants.dart';

class MapController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();
  final StorageService _storage = Get.find<StorageService>();
  final WsService _ws = Get.find<WsService>();
  final LocationReporterService _reporter = Get.find<LocationReporterService>();

  final memberLocations = <MemberLocation>[].obs;
  final isLoading = false.obs;
  final error = RxnString();
  final connectionStatus = ConnectionStatus.disconnected.obs;

  Timer? _staleRefreshTimer;
  String? _subscribedTeamId;

  String? get activeTeamId => _storage.read<String>(AppConstants.activeTeamKey);

  @override
  void onInit() {
    super.onInit();

    // Bind WS connection status
    ever(_ws.status, (status) {
      connectionStatus.value = status;
      if (status == ConnectionStatus.connected) {
        _onWsConnected();
      }
    });

    // Listen for real-time location updates
    _ws.on('member_location', _onMemberLocation);

    // Load initial data via HTTP
    _loadLocations();

    // Connect WebSocket if not already connected
    _ws.connect();

    // Start GPS reporting via the global service
    _reporter.startReporting();

    // Refresh every 60s to update stale indicators
    _staleRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => memberLocations.refresh(),
    );
  }

  @override
  void onClose() {
    _ws.off('member_location', _onMemberLocation);
    _staleRefreshTimer?.cancel();
    if (_subscribedTeamId != null) {
      _ws.leaveTeamChannel(_subscribedTeamId!);
    }
    super.onClose();
  }

  void _onWsConnected() {
    final teamId = activeTeamId;
    if (teamId != null) {
      _ws.joinTeamChannel(teamId);
      _subscribedTeamId = teamId;
    }
  }

  void _onMemberLocation(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;

    final updated = MemberLocation(
      userId: userId,
      nickname: data['nickname'] ?? _findNickname(userId),
      avatarUrl: data['avatar_url'],
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      altitude: (data['altitude'] as num?)?.toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      recordedAt: data['updated_at'] ?? DateTime.now().toIso8601String(),
    );

    // Update existing member or add new one
    final index = memberLocations.indexWhere((m) => m.userId == userId);
    if (index >= 0) {
      memberLocations[index] = updated;
    } else {
      memberLocations.add(updated);
    }
  }

  String _findNickname(String userId) {
    final existing = memberLocations.where((m) => m.userId == userId);
    return existing.isNotEmpty ? existing.first.nickname : '...';
  }

  Future<void> _loadLocations() async {
    final teamId = activeTeamId;
    if (teamId == null) return;

    try {
      memberLocations.value =
          await _locationService.getTeamLocations(teamId);
    } catch (_) {
      // Silent fail, keep last positions
    }
  }

  Future<void> refreshLocations() async {
    isLoading.value = true;
    error.value = null;
    try {
      await _loadLocations();
    } catch (e) {
      error.value = '加载位置信息失败';
    } finally {
      isLoading.value = false;
    }
  }

  void setActiveTeam(String teamId) {
    // Unsubscribe from old team
    if (_subscribedTeamId != null) {
      _ws.leaveTeamChannel(_subscribedTeamId!);
    }

    _storage.write(AppConstants.activeTeamKey, teamId);

    // Subscribe to new team
    if (_ws.status.value == ConnectionStatus.connected) {
      _ws.joinTeamChannel(teamId);
    }
    _subscribedTeamId = teamId;

    _loadLocations();
  }
}
