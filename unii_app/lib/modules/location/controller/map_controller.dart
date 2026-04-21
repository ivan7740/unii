import 'dart:async';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/location.dart';
import '../../../services/location_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/ws_service.dart';
import '../../../services/location_reporter_service.dart';
import '../../../utils/constants.dart';
import 'package:flutter_map/flutter_map.dart' as fm;

class MapController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();
  final StorageService _storage = Get.find<StorageService>();
  final WsService _ws = Get.find<WsService>();
  final LocationReporterService _reporter = Get.find<LocationReporterService>();

  final memberLocations = <MemberLocation>[].obs;
  final isLoading = false.obs;
  final error = RxnString();
  final connectionStatus = ConnectionStatus.disconnected.obs;
  final mapStyle = 'standard'.obs;
  final fmController = fm.MapController();
  final mapCamera = Rxn<fm.MapCamera>();

  Timer? _staleRefreshTimer;
  String? _subscribedTeamId;

  String? get activeTeamId => _storage.read<String>(AppConstants.activeTeamKey);

  static String tileUrl(String style) {
    const urls = {
      'standard': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'satellite':
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'terrain': 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    };
    return urls[style] ?? urls['standard']!;
  }

  static String formatDistance(double meters) {
    if (meters < 100) return '< 100 m';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String? distanceTo(MemberLocation member) {
    final pos = _reporter.lastPosition.value;
    if (pos == null) return null;
    final meters = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      member.latitude,
      member.longitude,
    );
    return formatDistance(meters);
  }

  void onMapEvent(fm.MapEvent event) {
    mapCamera.value = event.camera;
  }

  @override
  void onInit() {
    super.onInit();
    final savedStyle = _storage.read<String>(AppConstants.mapStyleKey);
    if (savedStyle != null) mapStyle.value = savedStyle;

    // Bind WS connection status
    ever(_ws.status, (status) {
      connectionStatus.value = status;
      if (status == ConnectionStatus.connected) {
        _onWsConnected();
      }
    });

    // Listen for real-time location updates
    _ws.on('member_location', _onMemberLocation);
    _ws.on('member_online', _onMemberOnline);
    _ws.on('team_online_members', _onTeamOnlineMembers);

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
    _ws.off('member_online', _onMemberOnline);
    _ws.off('team_online_members', _onTeamOnlineMembers);
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

  void _onMemberOnline(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    final online = data['online'] as bool? ?? false;
    if (userId == null) return;
    final index = memberLocations.indexWhere((m) => m.userId == userId);
    if (index >= 0) {
      memberLocations[index] = memberLocations[index].copyWith(isOnline: online);
    }
  }

  void _onTeamOnlineMembers(Map<String, dynamic> data) {
    final userIds = (data['user_ids'] as List?)?.cast<String>() ?? [];
    for (var i = 0; i < memberLocations.length; i++) {
      final isOnline = userIds.contains(memberLocations[i].userId);
      if (memberLocations[i].isOnline != isOnline) {
        memberLocations[i] = memberLocations[i].copyWith(isOnline: isOnline);
      }
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

  void setMapStyle(String style) {
    mapStyle.value = style;
    _storage.write(AppConstants.mapStyleKey, style);
  }
}
