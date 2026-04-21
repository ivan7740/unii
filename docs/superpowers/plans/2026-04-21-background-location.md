# Background Location Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep reporting location at 60s intervals while the app is in the background, using an Android foreground service notification to stay alive.

**Architecture:** Extend `LocationReporterService` — on `AppLifecycleState.paused`, switch the timer to 60s and (Android only) start a `getPositionStream` with `ForegroundNotificationConfig` to create a persistent foreground service. On `resumed`, cancel the stream and restore the user-selected frequency.

**Tech Stack:** Flutter, geolocator ^13.0.2 (already in pubspec), dart:io (Platform.isAndroid)

---

## File Structure

| File | Change |
|------|--------|
| `lib/utils/constants.dart` | Add `frequencyBackground = 60` |
| `lib/services/location_reporter_service.dart` | Full rewrite with background support |
| `test/widget_test.dart` | Add constant test |

---

### Task 1: Add frequencyBackground constant and test

**Files:**
- Modify: `lib/utils/constants.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the bottom of `test/widget_test.dart`, inside `main()`:

```dart
test('frequencyBackground constant is 60 seconds', () {
  expect(AppConstants.frequencyBackground, 60);
});
```

Also add the import at the top if not present:
```dart
import 'package:unii_app/utils/constants.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: FAIL — `frequencyBackground` undefined.

- [ ] **Step 3: Add the constant**

In `lib/utils/constants.dart`, add inside `AppConstants` after `frequencyHighAccuracy`:

```dart
static const int frequencyBackground = 60;
```

Final constants section looks like:
```dart
  // 位置更新频率（秒）
  static const int frequencyPowerSave = 30;
  static const int frequencyStandard = 10;
  static const int frequencyHighAccuracy = 3;
  static const int frequencyBackground = 60;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/utils/constants.dart unii_app/test/widget_test.dart && git commit -m "feat(location): add frequencyBackground constant (60s)"
```

---

### Task 2: Rewrite LocationReporterService with background support

**Files:**
- Modify: `lib/services/location_reporter_service.dart`

- [ ] **Step 1: Replace the file with the new implementation**

Full replacement of `lib/services/location_reporter_service.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../utils/constants.dart';
import 'location_service.dart';
import 'storage_service.dart';
import 'ws_service.dart';

class LocationReporterService extends GetxService with WidgetsBindingObserver {
  final StorageService _storage = Get.find<StorageService>();
  final WsService _ws = Get.find<WsService>();
  final LocationService _locationService = Get.find<LocationService>();

  final isReporting = false.obs;
  final lastPosition = Rxn<Position>();

  Timer? _reportTimer;
  StreamSubscription<Position>? _backgroundStream;
  bool _permissionGranted = false;
  bool _isInBackground = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportTimer?.cancel();
    _backgroundStream?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _exitBackground();
    } else if (state == AppLifecycleState.paused) {
      _enterBackground();
    }
  }

  /// Start periodic location reporting. Call after login.
  Future<void> startReporting() async {
    if (isReporting.value) return;
    if (!_storage.isLoggedIn) return;

    if (!_permissionGranted) {
      _permissionGranted = await _checkAndRequestPermission();
      if (!_permissionGranted) return;
    }

    isReporting.value = true;
    _scheduleTimer(_currentFrequency());
    await _reportCurrentLocation();
  }

  /// Stop all reporting. Call on logout.
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _backgroundStream?.cancel();
    _backgroundStream = null;
    isReporting.value = false;
    _isInBackground = false;
  }

  /// Restart timer with current frequency setting (foreground only).
  void updateFrequency() {
    if (!isReporting.value || _isInBackground) return;
    _reportTimer?.cancel();
    _scheduleTimer(_currentFrequency());
  }

  void _enterBackground() {
    if (!isReporting.value) return;
    _isInBackground = true;
    _reportTimer?.cancel();
    _scheduleTimer(AppConstants.frequencyBackground);
    if (Platform.isAndroid) {
      _startBackgroundStream();
    }
  }

  void _exitBackground() {
    _isInBackground = false;
    _backgroundStream?.cancel();
    _backgroundStream = null;
    if (!isReporting.value) {
      startReporting();
    } else {
      _reportTimer?.cancel();
      _scheduleTimer(_currentFrequency());
    }
  }

  /// Android only: start a position stream with foreground service notification
  /// so the OS keeps the process alive in the background.
  void _startBackgroundStream() {
    _backgroundStream?.cancel();
    _backgroundStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'UNII 位置共享',
          notificationText: '正在后台共享位置给团队成员',
          enableWakeLock: true,
        ),
      ),
    ).listen((position) {
      lastPosition.value = position;
    });
  }

  int _currentFrequency() {
    return _storage.read<int>(AppConstants.locationFrequencyKey) ??
        AppConstants.frequencyStandard;
  }

  void _scheduleTimer(int seconds) {
    _reportTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _reportCurrentLocation(),
    );
  }

  Future<void> _reportCurrentLocation() async {
    final activeTeamId = _storage.read<String>(AppConstants.activeTeamKey);
    if (activeTeamId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _isInBackground
              ? LocationAccuracy.medium
              : LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      lastPosition.value = position;

      if (_ws.status.value == ConnectionStatus.connected) {
        _ws.sendLocationUpdate(
          teamId: activeTeamId,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: position.speed,
        );
      } else {
        await _locationService.reportLocation(
          teamId: activeTeamId,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: position.speed,
        );
      }
    } catch (_) {
      // GPS read failed — skip this cycle
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    // Upgrade to always for background access (gracefully degrades if denied)
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }

    return true;
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/services/location_reporter_service.dart`
Expected: No issues found.

- [ ] **Step 3: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/services/location_reporter_service.dart && git commit -m "feat(location): add background location support with 60s interval and Android foreground service"
```

---

### Task 3: Final verification

**Files:** (none)

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 3 tests pass.

- [ ] **Step 3: Fix any issues if found**

If errors found, fix and commit:
```bash
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(location): resolve background location analysis issues"
```
