import 'dart:async';

import 'package:get/get.dart';

import '../../../models/location.dart';
import '../../../services/location_service.dart';
import '../../../utils/track_utils.dart';

class TrackController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();

  // ── 原有状态 ──────────────────────────────────────────────────
  final trackPoints = <TrackPoint>[].obs;
  final currentIndex = 0.obs;
  final isPlaying = false.obs;
  final isLoading = false.obs;
  final error = RxnString();

  late String userId;
  late String teamId;
  late String nickname;

  Timer? _playTimer;

  // ── 时间范围状态 ───────────────────────────────────────────────
  /// 'today' | 'yesterday' | '3days' | 'custom'
  final selectedPreset = 'today'.obs;
  final customStart = Rxn<DateTime>();
  final customEnd = Rxn<DateTime>();

  // ── 精度状态（D-P 简化）────────────────────────────────────────
  /// 0=高(5m)  1=中(15m)  2=低(50m)
  final precisionIndex = 1.obs;

  /// 地图用精简后的点集（可能与 trackPoints 相同，当点数 < 100 时）
  final simplifiedPoints = <TrackPoint>[].obs;

  // ── 计算属性 ──────────────────────────────────────────────────
  TrackPoint? get currentPoint =>
      trackPoints.isNotEmpty ? trackPoints[currentIndex.value] : null;

  String get currentTimeText {
    final point = currentPoint;
    if (point == null) return '--:--:--';
    final dt = DateTime.tryParse(point.recordedAt);
    if (dt == null) return '--:--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String get startTimeText =>
      _formatTime(trackPoints.isNotEmpty ? trackPoints.first.recordedAt : null);
  String get endTimeText =>
      _formatTime(trackPoints.isNotEmpty ? trackPoints.last.recordedAt : null);

  /// 用于 AppBar 副标题显示的时间范围摘要
  String get presetLabel {
    switch (selectedPreset.value) {
      case 'today':
        return '今天';
      case 'yesterday':
        return '昨天';
      case '3days':
        return '近3天';
      case 'custom':
        final s = customStart.value;
        final e = customEnd.value;
        if (s != null && e != null) {
          return '${s.month}/${s.day} – ${e.month}/${e.day}';
        }
        return '自定义';
      default:
        return '今天';
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── 生命周期 ──────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    userId = args['user_id'] as String;
    teamId = args['team_id'] as String;
    nickname = args['nickname'] as String;
    loadTrack();
  }

  @override
  void onClose() {
    _playTimer?.cancel();
    super.onClose();
  }

  // ── 公开方法 ──────────────────────────────────────────────────

  /// 切换快捷时间范围并重新加载
  void changePreset(String preset) {
    selectedPreset.value = preset;
    loadTrack();
  }

  /// 设置自定义时间范围并重新加载
  void setCustomRange(DateTime start, DateTime end) {
    customStart.value = start;
    customEnd.value = end;
    selectedPreset.value = 'custom';
    loadTrack();
  }

  /// 调整 D-P 精度级别（0/1/2），实时重新简化，不重新请求接口
  void changePrecision(int index) {
    precisionIndex.value = index;
    _applySimplification();
  }

  Future<void> loadTrack() async {
    isLoading.value = true;
    error.value = null;
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      switch (selectedPreset.value) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
        case 'yesterday':
          final y = now.subtract(const Duration(days: 1));
          start = DateTime(y.year, y.month, y.day);
          end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        case '3days':
          final d = now.subtract(const Duration(days: 3));
          start = DateTime(d.year, d.month, d.day);
        case 'custom':
          start = customStart.value ?? DateTime(now.year, now.month, now.day);
          end = customEnd.value ?? now;
        default:
          start = DateTime(now.year, now.month, now.day);
      }

      final points = await _locationService.getUserTrack(
        userId,
        teamId: teamId,
        start: start.toUtc().toIso8601String(),
        end: end.toUtc().toIso8601String(),
      );
      trackPoints.value = points;
      currentIndex.value = 0;
      _applySimplification();
    } catch (e) {
      error.value = '加载轨迹失败';
    } finally {
      isLoading.value = false;
    }
  }

  void play() {
    if (trackPoints.isEmpty) return;
    if (currentIndex.value >= trackPoints.length - 1) {
      currentIndex.value = 0;
    }
    isPlaying.value = true;
    _playTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (currentIndex.value >= trackPoints.length - 1) {
        pause();
        return;
      }
      currentIndex.value++;
    });
  }

  void pause() {
    _playTimer?.cancel();
    _playTimer = null;
    isPlaying.value = false;
  }

  void seekTo(int index) {
    pause();
    currentIndex.value = index.clamp(0, trackPoints.length - 1);
  }

  // ── 私有 ──────────────────────────────────────────────────────

  void _applySimplification() {
    simplifiedPoints.value = TrackUtils.simplify(
      trackPoints,
      TrackUtils.tolerances[precisionIndex.value],
    );
  }
}
