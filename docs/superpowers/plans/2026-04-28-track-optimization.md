# 轨迹优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 unii_app 轨迹页添加时间范围选择器（今天/昨天/近3天/自定义）和 Douglas-Peucker 精简滑块，减少地图渲染点数同时保留回放精度。

**Architecture:** 纯前端方案，后端不改动。新建 `TrackUtils.simplify()` 提供 RDP 算法；`TrackController` 新增时间范围状态和精度状态；`TrackView` 新增 AppBar 日历按钮（打开时间 Bottom Sheet）和控制面板精度滑块。地图 Polyline 使用简化点集，时间轴 Slider 仍用原始点集。

**Tech Stack:** Flutter 3.x, GetX, flutter_map, dart:math

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `unii_app/lib/utils/track_utils.dart` | RDP 算法实现 |
| 新建 | `unii_app/test/utils/track_utils_test.dart` | TrackUtils 单元测试 |
| 修改 | `unii_app/lib/modules/location/controller/track_controller.dart` | 时间范围 + 精度状态 + 简化逻辑 |
| 修改 | `unii_app/lib/modules/location/view/track_view.dart` | 时间 Sheet + 精度滑块 |
| 修改 | `todolist.md` | 标记 Phase 7 轨迹优化为完成 |

---

### Task 1: TrackUtils — RDP 算法 + 单元测试

**Files:**
- Create: `unii_app/lib/utils/track_utils.dart`
- Create: `unii_app/test/utils/track_utils_test.dart`

- [ ] **Step 1: 创建 test 目录**

```bash
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii_app/test/utils
```

- [ ] **Step 2: 写失败测试**

创建 `unii_app/test/utils/track_utils_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:unii_app/models/location.dart';
import 'package:unii_app/utils/track_utils.dart';

TrackPoint pt(double lat, double lng) => TrackPoint(
      latitude: lat,
      longitude: lng,
      recordedAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('TrackUtils.simplify', () {
    test('returns original list when points < 100', () {
      final points = List.generate(50, (i) => pt(39.0 + i * 0.001, 116.0));
      final result = TrackUtils.simplify(points, 15.0);
      expect(result, same(points));
    });

    test('collinear points simplified to just endpoints', () {
      // 200 evenly-spaced collinear points along longitude axis
      final points = List.generate(
          200, (i) => pt(39.0, 116.0 + i * 0.0001));
      final result = TrackUtils.simplify(points, 15.0);
      expect(result.length, 2);
      expect(result.first.longitude, closeTo(116.0, 1e-9));
      expect(result.last.longitude, closeTo(116.0 + 199 * 0.0001, 1e-9));
    });

    test('significant bend is preserved', () {
      // 200 points: straight east then sharp north turn
      final straight = List.generate(100, (i) => pt(39.0, 116.0 + i * 0.001));
      final turn = List.generate(100, (i) => pt(39.0 + (i + 1) * 0.001, 116.099));
      final points = [...straight, ...turn];
      final result = TrackUtils.simplify(points, 5.0);
      // Must keep more than 2 points (the bend is significant)
      expect(result.length, greaterThan(2));
      // Must keep start and end
      expect(result.first.longitude, closeTo(116.0, 1e-9));
      expect(result.last.latitude, closeTo(39.0 + 100 * 0.001, 1e-9));
    });

    test('lower precision produces fewer points', () {
      final points = List.generate(200, (i) {
        // Sinusoidal path
        final lat = 39.0 + (i % 10) * 0.0001;
        final lng = 116.0 + i * 0.001;
        return pt(lat, lng);
      });
      final high = TrackUtils.simplify(points, TrackUtils.tolerances[0]);
      final low = TrackUtils.simplify(points, TrackUtils.tolerances[2]);
      expect(low.length, lessThanOrEqualTo(high.length));
    });
  });
}
```

- [ ] **Step 3: 运行确认失败**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/utils/track_utils_test.dart 2>&1 | head -10
```

期望：编译错误 `target of URI doesn't exist: 'package:unii_app/utils/track_utils.dart'`

- [ ] **Step 4: 创建 `unii_app/lib/utils/track_utils.dart`**

```dart
import 'dart:math';
import '../models/location.dart';

class TrackUtils {
  /// 容差级别（米）：索引 0=高精度 5m, 1=标准 15m, 2=低精度 50m
  static const tolerances = [5.0, 15.0, 50.0];

  static const _minPointsToSimplify = 100;

  /// Ramer–Douglas–Peucker 简化。
  /// 点数 < 100 时直接返回原列表（不复制）。
  /// toleranceMeters 使用经纬度欧氏近似（1° ≈ 111 000 m）。
  static List<TrackPoint> simplify(
      List<TrackPoint> points, double toleranceMeters) {
    if (points.length < _minPointsToSimplify) return points;
    final epsilon = toleranceMeters / 111000.0;
    return _rdp(points, epsilon);
  }

  static List<TrackPoint> _rdp(List<TrackPoint> points, double epsilon) {
    if (points.length < 3) return List.of(points);
    double maxDist = 0;
    int index = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDist(points[i], points.first, points.last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, index + 1), epsilon);
      final right = _rdp(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  /// 点 p 到线段 (start, end) 的垂直距离（度数单位，与 epsilon 量纲一致）
  static double _perpendicularDist(
      TrackPoint p, TrackPoint start, TrackPoint end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      final ex = p.longitude - start.longitude;
      final ey = p.latitude - start.latitude;
      return sqrt(ex * ex + ey * ey);
    }
    final t = ((p.longitude - start.longitude) * dx +
            (p.latitude - start.latitude) * dy) /
        lenSq;
    final tc = t.clamp(0.0, 1.0);
    final px = start.longitude + tc * dx;
    final py = start.latitude + tc * dy;
    final ex = p.longitude - px;
    final ey = p.latitude - py;
    return sqrt(ex * ex + ey * ey);
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/utils/track_utils_test.dart 2>&1
```

期望：`+4: All tests passed!`

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/utils/track_utils.dart unii_app/test/utils/track_utils_test.dart && git commit -m "feat(track): add TrackUtils with Ramer-Douglas-Peucker simplification"
```

---

### Task 2: TrackController — 时间范围 + 精度状态

**Files:**
- Modify: `unii_app/lib/modules/location/controller/track_controller.dart`

现有文件路径：`unii_app/lib/modules/location/controller/track_controller.dart`

- [ ] **Step 1: 添加新状态字段和方法**

将整个 `track_controller.dart` 替换为以下内容（保留原有逻辑，扩充新字段）：

```dart
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
```

- [ ] **Step 2: 运行 analyze 确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/track_controller.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/track_controller.dart && git commit -m "feat(track): add time range presets and D-P precision control to TrackController"
```

---

### Task 3: TrackView — 时间 Sheet + 精度滑块

**Files:**
- Modify: `unii_app/lib/modules/location/view/track_view.dart`

- [ ] **Step 1: 替换 track_view.dart**

将 `unii_app/lib/modules/location/view/track_view.dart` 全部替换为以下内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../widgets/empty_state.dart';
import '../controller/track_controller.dart';

class TrackView extends GetView<TrackController> {
  const TrackView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${controller.nickname} 的轨迹'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Obx(() => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${controller.presetLabel}  ·  '
                  '${controller.trackPoints.length} 点 → 显示 ${controller.simplifiedPoints.length} 点',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                ),
              )),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '选择时间范围',
            onPressed: () => _showTimeRangeSheet(context),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(controller.error.value!,
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.loadTrack,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (controller.trackPoints.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.route_outlined,
            message: '暂无轨迹数据',
            hint: '开启定位后轨迹将在这里显示',
          );
        }

        // 地图用简化点，时间轴 Slider 用原始点
        final mapPoints = controller.simplifiedPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        final currentPoint = controller.currentPoint;

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapPoints.first,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.unii.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: mapPoints,
                        color: const Color(0xFF2196F3),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: mapPoints.first,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag,
                              size: 12, color: Colors.white),
                        ),
                      ),
                      Marker(
                        point: mapPoints.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag,
                              size: 12, color: Colors.white),
                        ),
                      ),
                      if (currentPoint != null)
                        Marker(
                          point: LatLng(currentPoint.latitude,
                              currentPoint.longitude),
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _buildControlPanel(context),
          ],
        );
      }),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放控制行（原有）
            Row(
              children: [
                Obx(() => IconButton(
                      icon: Icon(
                        controller.isPlaying.value
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      onPressed: controller.isPlaying.value
                          ? controller.pause
                          : controller.play,
                    )),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.currentIndex.value.toDouble(),
                        min: 0,
                        max: (controller.trackPoints.length - 1)
                            .toDouble()
                            .clamp(0, double.infinity),
                        onChanged: (v) => controller.seekTo(v.toInt()),
                      )),
                ),
                Obx(() => Text(
                      controller.currentTimeText,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    )),
              ],
            ),
            // 起止时间行（原有）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => Text(
                        controller.startTimeText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      )),
                  Obx(() => Text(
                        '${controller.trackPoints.length} 个点',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      )),
                  Obx(() => Text(
                        controller.endTimeText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 精度控制行（新增）
            Row(
              children: [
                Text(
                  '精度',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                Text(
                  '高',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.precisionIndex.value.toDouble(),
                        min: 0,
                        max: 2,
                        divisions: 2,
                        onChanged: (v) =>
                            controller.changePrecision(v.toInt()),
                      )),
                ),
                Text(
                  '低',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Obx(() => Text(
                      '${controller.simplifiedPoints.length} 点',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeRangeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TimeRangeSheet(controller: controller),
    );
  }
}

class _TimeRangeSheet extends StatefulWidget {
  final TrackController controller;
  const _TimeRangeSheet({required this.controller});

  @override
  State<_TimeRangeSheet> createState() => _TimeRangeSheetState();
}

class _TimeRangeSheetState extends State<_TimeRangeSheet> {
  late String _selectedPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.controller.selectedPreset.value;
    _customStart = widget.controller.customStart.value;
    _customEnd = widget.controller.customEnd.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择时间范围',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // 快捷选项
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'today': '今天',
                'yesterday': '昨天',
                '3days': '近3天',
                'custom': '自定义',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedPreset == entry.key,
                  onSelected: (_) {
                    setState(() => _selectedPreset = entry.key);
                    if (entry.key != 'custom') {
                      widget.controller.changePreset(entry.key);
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          // 自定义时间选择（仅当 custom 被选中时展开）
          if (_selectedPreset == 'custom') ...[
            const SizedBox(height: 16),
            _DateTimePicker(
              label: '开始',
              value: _customStart,
              onChanged: (dt) => setState(() => _customStart = dt),
            ),
            const SizedBox(height: 8),
            _DateTimePicker(
              label: '结束',
              value: _customEnd,
              onChanged: (dt) => setState(() => _customEnd = dt),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_customStart != null && _customEnd != null)
                    ? () {
                        widget.controller
                            .setCustomRange(_customStart!, _customEnd!);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('确认'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const _DateTimePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: now.subtract(const Duration(days: 30)),
                lastDate: now,
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay.fromDateTime(value ?? now),
              );
              if (time == null) return;
              onChanged(DateTime(
                  date.year, date.month, date.day,
                  time.hour, time.minute));
            },
            child: Text(
              value != null
                  ? '${value!.month}/${value!.day} '
                    '${value!.hour.toString().padLeft(2, '0')}:'
                    '${value!.minute.toString().padLeft(2, '0')}'
                  : '请选择',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/track_view.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 运行全量测试确认无回归**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1 | tail -3
```

期望：`+28: All tests passed!`（24 原有 + 4 新增 TrackUtils 测试）

- [ ] **Step 4: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/track_view.dart && git commit -m "feat(track): add time range bottom sheet and D-P precision slider to TrackView"
```

---

### Task 4: 更新 todolist.md

**Files:**
- Modify: `todolist.md`

- [ ] **Step 1: 将以下行**

```
- [ ] **[B]** 优化轨迹查询：时间范围筛选、Douglas-Peucker 轨迹简化
```

**改为：**

```
- [x] **[B]** 优化轨迹查询：时间范围筛选、Douglas-Peucker 轨迹简化（前端 RDP + 时间 Sheet）
```

- [ ] **Step 2: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add todolist.md && git commit -m "chore: mark Phase 7 track optimization as done"
```
