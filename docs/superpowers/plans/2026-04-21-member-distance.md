# Member Distance Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each team member's distance from the user's own GPS position in the bottom member panel of the map view.

**Architecture:** `MapController` gains a `static formatDistance(double meters)` helper (testable) and a `distanceTo(MemberLocation member)` method that reads `_reporter.lastPosition` and returns a formatted string or `null`. `MapView` adds an `Obx`-wrapped distance text to each member row so it updates reactively when `lastPosition` changes.

**Tech Stack:** Flutter, GetX, geolocator (already in pubspec)

---

## File Structure

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `static formatDistance()` and `distanceTo()` |
| `lib/modules/location/view/map_view.dart` | Add Obx-wrapped distance text to member panel rows |
| `test/widget_test.dart` | Add `formatDistance` unit tests |

---

### Task 1: Add formatDistance helper and distanceTo to MapController

**Files:**
- Modify: `lib/modules/location/controller/map_controller.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/widget_test.dart` inside `main()`, after existing tests:

```dart
test('MapController.formatDistance formats distances correctly', () {
  expect(app.MapController.formatDistance(50), '< 100 m');
  expect(app.MapController.formatDistance(99.9), '< 100 m');
  expect(app.MapController.formatDistance(100), '100 m');
  expect(app.MapController.formatDistance(350.6), '351 m');
  expect(app.MapController.formatDistance(999), '999 m');
  expect(app.MapController.formatDistance(1000), '1.0 km');
  expect(app.MapController.formatDistance(1234), '1.2 km');
});
```

Note: `app` alias is already imported from the map style task:
```dart
import 'package:unii_app/modules/location/controller/map_controller.dart' as app;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: FAIL — `formatDistance` not defined on `MapController`.

- [ ] **Step 3: Add formatDistance static method and distanceTo method**

In `lib/modules/location/controller/map_controller.dart`, add the import at the top (after existing imports):

```dart
import 'package:geolocator/geolocator.dart';
```

Then add inside `MapController` class, after the `tileUrl` static method:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: All 5 tests pass.

- [ ] **Step 5: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/map_controller.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/map_controller.dart unii_app/test/widget_test.dart && git commit -m "feat(map): add formatDistance helper and distanceTo method to MapController"
```

---

### Task 2: Add distance text to member panel rows in MapView

**Files:**
- Modify: `lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Add Obx-wrapped distance widget to each member row**

In `lib/modules/location/view/map_view.dart`, inside `_buildMemberPanel`'s `itemBuilder`, find the Row's children list. The current last two children are:

```dart
                        if (member.speed != null && member.speed! > 0)
                          Text(
                            '${member.speed!.toStringAsFixed(1)} m/s',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
```

Add the distance widget **before** `const Icon(Icons.chevron_right, ...)`:

```dart
                        if (member.speed != null && member.speed! > 0)
                          Text(
                            '${member.speed!.toStringAsFixed(1)} m/s',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        Obx(() {
                          final dist = controller.distanceTo(member);
                          if (dist == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              dist,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue.shade600),
                            ),
                          );
                        }),
                        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No issues found.

- [ ] **Step 3: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 5 tests pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/map_view.dart && git commit -m "feat(map): show member distance from my position in bottom panel"
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
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(map): resolve member distance analysis issues"
```
