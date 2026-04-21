# Map Style Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users switch the map tile layer between Standard, Satellite, and Terrain with a 3-button column in the top-left corner of the map, persisting the selection via Hive.

**Architecture:** `MapController` gains a `mapStyle` RxString, a static `tileUrl(style)` helper, and a `setMapStyle()` method that saves to Hive. `MapView` wraps `TileLayer` in `Obx` and adds a `_buildStyleButtons()` overlay at top-left.

**Tech Stack:** Flutter, GetX, flutter_map, Hive (via StorageService)

---

## File Structure

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `mapStyle` field, `static tileUrl()`, `setMapStyle()`, load from Hive in `onInit` |
| `lib/modules/location/view/map_view.dart` | Wrap TileLayer in Obx, add `_buildStyleButtons()` in Stack |
| `test/widget_test.dart` | Add `tileUrl` unit tests |

---

### Task 1: Add mapStyle to MapController with tileUrl helper

**Files:**
- Modify: `lib/modules/location/controller/map_controller.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart`, inside `main()`, after existing tests. Also add the import at the top:

```dart
import 'package:unii_app/modules/location/controller/map_controller.dart' as app;
```

Then add the test:

```dart
test('MapController.tileUrl returns correct tile URLs', () {
  expect(app.MapController.tileUrl('standard'), contains('openstreetmap.org'));
  expect(app.MapController.tileUrl('satellite'), contains('arcgisonline.com'));
  expect(app.MapController.tileUrl('terrain'), contains('opentopomap.org'));
  expect(app.MapController.tileUrl('unknown'), contains('openstreetmap.org'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: FAIL — `tileUrl` is not defined on `MapController`.

- [ ] **Step 3: Add mapStyle field, tileUrl helper, setMapStyle, and load from Hive**

In `lib/modules/location/controller/map_controller.dart`:

Add after `final connectionStatus = ConnectionStatus.disconnected.obs;` (line 19):

```dart
  final mapStyle = 'standard'.obs;
```

Add this static method anywhere inside the class (e.g., before `onInit`):

```dart
  static String tileUrl(String style) {
    const urls = {
      'standard': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'satellite':
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'terrain': 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    };
    return urls[style] ?? urls['standard']!;
  }
```

Add this public method (e.g., after `setActiveTeam`):

```dart
  void setMapStyle(String style) {
    mapStyle.value = style;
    _storage.write(AppConstants.mapStyleKey, style);
  }
```

In `onInit`, add after `super.onInit();`:

```dart
    final savedStyle = _storage.read<String>(AppConstants.mapStyleKey);
    if (savedStyle != null) mapStyle.value = savedStyle;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: All 4 tests pass.

- [ ] **Step 5: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/map_controller.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/map_controller.dart unii_app/test/widget_test.dart && git commit -m "feat(map): add mapStyle reactive field, tileUrl helper, and setMapStyle with Hive persistence"
```

---

### Task 2: Update MapView — Obx TileLayer + style button overlay

**Files:**
- Modify: `lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Replace the static TileLayer with an Obx-wrapped version**

In `lib/modules/location/view/map_view.dart`, find:

```dart
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.unii.app',
                ),
```

Replace with:

```dart
                Obx(() => TileLayer(
                      urlTemplate:
                          app.MapController.tileUrl(controller.mapStyle.value),
                      userAgentPackageName: 'com.unii.app',
                    )),
```

- [ ] **Step 2: Add the style button overlay to the Stack**

In `map_view.dart`, inside the `Stack`'s `children` list, add after the `FlutterMap` closing `)` and before `// 底部成员面板`:

```dart
            // 地图样式切换按钮
            Positioned(
              top: 48,
              left: 12,
              child: _buildStyleButtons(),
            ),
```

- [ ] **Step 3: Add the _buildStyleButtons method**

Add this method to `MapView`, after `_buildMemberPanel`:

```dart
  Widget _buildStyleButtons() {
    final styles = [
      ('standard', Icons.map, '标准'),
      ('satellite', Icons.satellite_alt, '卫星'),
      ('terrain', Icons.terrain, '地形'),
    ];
    return Obx(() => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: styles.map((s) {
              final isSelected = controller.mapStyle.value == s.$1;
              return IconButton(
                icon: Icon(
                  s.$2,
                  color: isSelected
                      ? Theme.of(Get.context!).colorScheme.primary
                      : Colors.grey.shade400,
                  size: 20,
                ),
                tooltip: s.$3,
                onPressed: () => controller.setMapStyle(s.$1),
                padding: const EdgeInsets.all(8),
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            }).toList(),
          ),
        ));
  }
```

- [ ] **Step 4: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No issues found.

- [ ] **Step 5: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/map_view.dart && git commit -m "feat(map): add map style switcher buttons and reactive TileLayer"
```

---

### Task 3: Final verification

**Files:** (none)

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 4 tests pass.

- [ ] **Step 3: Fix any issues if found**

If errors: fix and commit:
```bash
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(map): resolve map style switching analysis issues"
```
