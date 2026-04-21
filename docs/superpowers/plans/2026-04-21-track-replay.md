# Track Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a track replay page with Polyline visualization and time slider playback for viewing member location history.

**Architecture:** New TrackController loads track data via existing LocationService.getUserTrack(), manages playback state (currentIndex, isPlaying). TrackView renders a FlutterMap with Polyline + moving marker, and a bottom control panel with slider and play/pause. Accessed from map page bottom member panel via onTap.

**Tech Stack:** Flutter, GetX, flutter_map, latlong2, existing LocationService

---

## File Structure

| File | Role |
|------|------|
| `lib/modules/location/controller/track_controller.dart` | NEW: Load track, playback state, timer |
| `lib/modules/location/view/track_view.dart` | NEW: Map + Polyline + slider + controls |
| `lib/modules/location/binding/track_binding.dart` | NEW: Register TrackController |
| `lib/app/routes/app_pages.dart` | Add /track GetPage |
| `lib/modules/location/view/map_view.dart` | Add onTap to member panel items |

---

### Task 1: Create TrackController

**Files:**
- Create: `lib/modules/location/controller/track_controller.dart`

- [ ] **Step 1: Create the controller file**

```dart
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

  String get startTimeText => _formatTime(trackPoints.isNotEmpty ? trackPoints.first.recordedAt : null);
  String get endTimeText => _formatTime(trackPoints.isNotEmpty ? trackPoints.last.recordedAt : null);

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
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/track_controller.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/track_controller.dart && git commit -m "feat(track): create TrackController with data loading and playback logic"
```

---

### Task 2: Create TrackBinding

**Files:**
- Create: `lib/modules/location/binding/track_binding.dart`

- [ ] **Step 1: Create the binding file**

```dart
import 'package:get/get.dart';
import '../controller/track_controller.dart';

class TrackBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TrackController>(() => TrackController());
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/binding/track_binding.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/binding/track_binding.dart && git commit -m "feat(track): create TrackBinding"
```

---

### Task 3: Create TrackView

**Files:**
- Create: `lib/modules/location/view/track_view.dart`

- [ ] **Step 1: Create the view file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../controller/track_controller.dart';

class TrackView extends GetView<TrackController> {
  const TrackView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${controller.nickname} 的轨迹')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(controller.error.value!, style: TextStyle(color: Colors.grey.shade500)),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('暂无轨迹数据', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('今天还没有位置记录', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        final points = controller.trackPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        final currentPoint = controller.currentPoint;

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 15,
                  onMapReady: () {
                    // fitBounds handled below
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.unii.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: const Color(0xFF2196F3),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  // Start marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag, size: 12, color: Colors.white),
                        ),
                      ),
                      // End marker
                      Marker(
                        point: points.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag, size: 12, color: Colors.white),
                        ),
                      ),
                      // Current position marker
                      if (currentPoint != null)
                        Marker(
                          point: LatLng(currentPoint.latitude, currentPoint.longitude),
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
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
            Row(
              children: [
                Obx(() => IconButton(
                      icon: Icon(
                        controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: controller.isPlaying.value
                          ? controller.pause
                          : controller.play,
                    )),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.currentIndex.value.toDouble(),
                        min: 0,
                        max: (controller.trackPoints.length - 1).toDouble().clamp(0, double.infinity),
                        onChanged: (v) => controller.seekTo(v.toInt()),
                      )),
                ),
                Obx(() => Text(
                      controller.currentTimeText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => Text(
                        controller.startTimeText,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      )),
                  Obx(() => Text(
                        '${controller.trackPoints.length} 个点',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      )),
                  Obx(() => Text(
                        controller.endTimeText,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/track_view.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/track_view.dart && git commit -m "feat(track): create TrackView with Polyline, slider, and playback controls"
```

---

### Task 4: Register /track route in app_pages.dart

**Files:**
- Modify: `lib/app/routes/app_pages.dart`

- [ ] **Step 1: Add imports**

At the top of the file, add after existing location imports:

```dart
import '../../modules/location/binding/track_binding.dart';
import '../../modules/location/view/track_view.dart';
```

- [ ] **Step 2: Add the GetPage entry**

In the `pages` list, add after the chat route entry:

```dart
GetPage(
  name: Routes.track,
  page: () => const TrackView(),
  binding: TrackBinding(),
),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/app/routes/app_pages.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/app/routes/app_pages.dart && git commit -m "feat(track): register /track route with TrackBinding"
```

---

### Task 5: Add onTap navigation from member panel

**Files:**
- Modify: `lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Wrap member panel Row in GestureDetector**

In `_buildMemberPanel`, the `ListView.builder` renders each member as a `Padding` containing a `Row`. Wrap the `Padding` widget with a `GestureDetector` that navigates to the track page.

Find (inside `itemBuilder`):
```dart
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
```

Replace with:
```dart
return GestureDetector(
  onTap: () => Get.toNamed('/track', arguments: {
    'user_id': member.userId,
    'team_id': controller.activeTeamId,
    'nickname': member.nickname,
  }),
  child: Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
```

And add the matching closing `)` for the `GestureDetector` — find the closing of the `Padding`'s `child: Row(...)`:

After the Row's closing `),` and Padding's closing `);`, change to:

```dart
    ),  // Row
  ),    // Padding
);      // GestureDetector
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/map_view.dart && git commit -m "feat(track): add onTap navigation from member panel to track view"
```

---

### Task 6: Final verification

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No errors.

- [ ] **Step 2: Fix any issues if needed**

If errors found, fix and commit:
```bash
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(track): resolve analysis issues"
```
