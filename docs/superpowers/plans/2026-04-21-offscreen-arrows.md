# Off-Screen Member Direction Arrows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show rotated navigation arrow icons at the map edges pointing toward team members who are off-screen, with truncated nicknames.

**Architecture:** GetX `MapController` gains a flutter_map `MapController` instance (`fmController`), a reactive `Rxn<MapCamera>` (`mapCamera`), and an `onMapEvent` callback. `FlutterMap` is wired to these. `MapView` adds a full-screen `IgnorePointer` overlay that uses `LayoutBuilder` + `Obx` to compute and render rotated arrows at map edges using `latLngToScreenPoint`.

**Tech Stack:** Flutter, GetX, flutter_map 7.0.2 (already in pubspec)

---

## File Structure

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `fm` import, `fmController`, `mapCamera`, `onMapEvent()` |
| `lib/modules/location/view/map_view.dart` | Add `dart:math` import, wire FlutterMap, add arrow overlay + `_buildOffScreenArrows()` + `static _clampToEdge()` |

---

### Task 1: Add fmController, mapCamera, and onMapEvent to MapController

**Files:**
- Modify: `lib/modules/location/controller/map_controller.dart`

- [ ] **Step 1: Add flutter_map import**

In `lib/modules/location/controller/map_controller.dart`, add after the last existing import (line 9, after `import '../../../utils/constants.dart';`):

```dart
import 'package:flutter_map/flutter_map.dart' as fm;
```

- [ ] **Step 2: Add fmController and mapCamera fields**

After `final mapStyle = 'standard'.obs;` (line 21), add:

```dart
  final fmController = fm.MapController();
  final mapCamera = Rxn<fm.MapCamera>();
```

- [ ] **Step 3: Add onMapEvent method**

Add after the `distanceTo` method (after its closing `}`), before `onInit`:

```dart
  void onMapEvent(fm.MapEvent event) {
    mapCamera.value = event.camera;
  }
```

- [ ] **Step 4: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/map_controller.dart`
Expected: No issues found.

- [ ] **Step 5: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/map_controller.dart && git commit -m "feat(map): add fmController, mapCamera, and onMapEvent to MapController"
```

---

### Task 2: Wire FlutterMap and add arrow overlay to MapView

**Files:**
- Modify: `lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Add dart:math import**

In `lib/modules/location/view/map_view.dart`, the first line is `import 'dart:ui' as ui;`. Add after it:

```dart
import 'dart:math' as math;
```

- [ ] **Step 2: Wire FlutterMap with mapController and onMapEvent**

Find:

```dart
            FlutterMap(
              options: MapOptions(
                initialCenter: members.isNotEmpty
                    ? LatLng(members.first.latitude, members.first.longitude)
                    : const LatLng(39.9042, 116.4074), // 默认北京
                initialZoom: 14,
              ),
```

Replace with:

```dart
            FlutterMap(
              mapController: controller.fmController,
              options: MapOptions(
                initialCenter: members.isNotEmpty
                    ? LatLng(members.first.latitude, members.first.longitude)
                    : const LatLng(39.9042, 116.4074), // 默认北京
                initialZoom: 14,
                onMapEvent: controller.onMapEvent,
              ),
```

- [ ] **Step 3: Add arrow overlay as last Stack child**

Find the closing of the refresh FAB `Positioned` block. After its closing `),` and before the Stack's closing `],`, add:

```dart
            // 屏幕外成员方向箭头
            Positioned.fill(
              child: IgnorePointer(
                child: _buildOffScreenArrows(),
              ),
            ),
```

The Stack children order becomes:
1. FlutterMap
2. Style buttons Positioned
3. Member panel Positioned
4. Refresh FAB Positioned
5. Arrow overlay Positioned.fill ← new, last

- [ ] **Step 4: Add _buildOffScreenArrows method**

Add after `_buildStyleButtons()` method, before the `_MemberMarker` class definition:

```dart
  Widget _buildOffScreenArrows() {
    return Obx(() {
      final camera = controller.mapCamera.value;
      final members = controller.memberLocations;
      if (camera == null || members.isEmpty) return const SizedBox.shrink();

      return LayoutBuilder(
        builder: (context, constraints) {
          const padding = 24.0;
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final center = Offset(w / 2, h / 2);

          final arrows = <Widget>[];
          for (final member in members) {
            final screenPt = camera.latLngToScreenPoint(
              LatLng(member.latitude, member.longitude),
            );
            final pt = Offset(screenPt.x.toDouble(), screenPt.y.toDouble());

            // Skip members that are on screen
            if (pt.dx >= padding &&
                pt.dx <= w - padding &&
                pt.dy >= padding &&
                pt.dy <= h - padding) {
              continue;
            }

            final dx = pt.dx - center.dx;
            final dy = pt.dy - center.dy;
            final angle = math.atan2(dy, dx) + math.pi / 2;

            final edgePt = _clampToEdge(center, pt, w, h, padding);
            final label = member.nickname.length > 4
                ? '${member.nickname.substring(0, 4)}..'
                : member.nickname;

            arrows.add(
              Positioned(
                left: edgePt.dx - 16,
                top: edgePt.dy - 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: angle,
                      child: const Icon(
                        Icons.navigation,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (arrows.isEmpty) return const SizedBox.shrink();
          return Stack(children: arrows);
        },
      );
    });
  }
```

- [ ] **Step 5: Add _clampToEdge static method**

Add immediately after `_buildOffScreenArrows()`, before `_MemberMarker`:

```dart
  static Offset _clampToEdge(
    Offset center,
    Offset target,
    double w,
    double h,
    double padding,
  ) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;

    double scale = double.infinity;
    if (dx > 0) scale = math.min(scale, (w - padding - center.dx) / dx);
    if (dx < 0) scale = math.min(scale, (padding - center.dx) / dx);
    if (dy > 0) scale = math.min(scale, (h - padding - center.dy) / dy);
    if (dy < 0) scale = math.min(scale, (padding - center.dy) / dy);

    return Offset(
      (center.dx + dx * scale).clamp(padding, w - padding),
      (center.dy + dy * scale).clamp(padding, h - padding),
    );
  }
```

- [ ] **Step 6: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No issues found.

- [ ] **Step 7: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 5 tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/map_view.dart && git commit -m "feat(map): add off-screen member direction arrows at map edges"
```

---

### Task 3: Final verification

**Files:** (none)

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 5 tests pass.

- [ ] **Step 3: Fix any issues if found**

If errors: fix and commit:
```bash
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(map): resolve off-screen arrows analysis issues"
```
