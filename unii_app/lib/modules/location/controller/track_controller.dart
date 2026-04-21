import 'dart:async';

import 'package:get/get.dart';

import '../../../models/location.dart';
import '../../../services/location_service.dart';

class TrackController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();

  final trackPoints = <TrackPoint>[].obs;
  final currentIndex = 0.obs;
  final isPlaying = false.obs;
  final isLoading = false.obs;
  final error = RxnString();

  late String userId;
  late String teamId;
  late String nickname;

  Timer? _playTimer;

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

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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

  Future<void> loadTrack() async {
    isLoading.value = true;
    error.value = null;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final points = await _locationService.getUserTrack(
        userId,
        teamId: teamId,
        start: startOfDay.toIso8601String(),
        end: now.toIso8601String(),
      );
      trackPoints.value = points;
      currentIndex.value = 0;
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
}
