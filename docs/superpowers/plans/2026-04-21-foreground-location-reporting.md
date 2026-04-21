# Foreground Location Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate real GPS via geolocator, report location in foreground only, and show stale markers (grey + time ago) when a member's position is older than 5 minutes.

**Architecture:** New `LocationReporterService` (GetxService + WidgetsBindingObserver) owns GPS + timer + reporting. MapController is simplified to only manage map state. MemberMarker gains stale styling based on `recordedAt`.

**Tech Stack:** Flutter, GetX, geolocator (already in pubspec), flutter_map, WsService/LocationService (existing)

---

## File Structure

| File | Role |
|------|------|
| `lib/models/location.dart` | Add `isStale` getter + `timeAgoText` helper to MemberLocation |
| `lib/services/location_reporter_service.dart` | NEW: GPS read + periodic report + lifecycle |
| `lib/main.dart` | Register LocationReporterService |
| `lib/modules/location/controller/map_controller.dart` | Remove reporting logic, add 60s stale refresh timer |
| `lib/modules/location/view/map_view.dart` | Update _MemberMarker + member panel for stale display |
| `lib/modules/settings/controller/settings_controller.dart` | Call updateFrequency() on change |
| `lib/services/auth_service.dart` | Call stopReporting() on logout |

---

### Task 1: Add stale helpers to MemberLocation model

**Files:**
- Modify: `lib/models/location.dart:38-92`

- [ ] **Step 1: Add `isStale` getter and `timeAgoText` to MemberLocation**

Add these members to the `MemberLocation` class:

```dart
/// Whether this location is older than 5 minutes
bool get isStale {
  final recorded = DateTime.tryParse(recordedAt);
  if (recorded == null) return true;
  return DateTime.now().difference(recorded).inMinutes >= 5;
}

/// Human-readable time ago string (only shown when stale)
String get timeAgoText {
  final recorded = DateTime.tryParse(recordedAt);
  if (recorded == null) return '';
  final diff = DateTime.now().difference(recorded);
  if (diff.inDays > 0) return '${diff.inDays}天前';
  if (diff.inHours > 0) return '${diff.inHours}小时前';
  return '${diff.inMinutes}分钟前';
}
```

Add them after the `copyWith` method, before the closing `}` of the class.

- [ ] **Step 2: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/models/location.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/models/location.dart
git commit -m "feat(location): add isStale and timeAgoText helpers to MemberLocation"
```

---

### Task 2: Create LocationReporterService

**Files:**
- Create: `lib/services/location_reporter_service.dart`

- [ ] **Step 1: Create the service file**

```dart
import 'dart:async';

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
  bool _permissionGranted = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startReporting();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      stopReporting();
    }
  }

  /// Start periodic location reporting. Call after login / app resume.
  Future<void> startReporting() async {
    if (isReporting.value) return;
    if (!_storage.isLoggedIn) return;

    if (!_permissionGranted) {
      _permissionGranted = await _checkAndRequestPermission();
      if (!_permissionGranted) return;
    }

    isReporting.value = true;
    _scheduleTimer();
    // Report immediately on start
    await _reportCurrentLocation();
  }

  /// Stop periodic location reporting. Call on logout / app pause.
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    isReporting.value = false;
  }

  /// Restart timer with current frequency setting.
  void updateFrequency() {
    if (!isReporting.value) return;
    _reportTimer?.cancel();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    final seconds = _storage.read<int>(AppConstants.locationFrequencyKey) ??
        AppConstants.frequencyStandard;
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
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

    return true;
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/services/location_reporter_service.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/location_reporter_service.dart
git commit -m "feat(location): create LocationReporterService with GPS + periodic reporting"
```

---

### Task 3: Register service in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import and register the service**

Add import at the top (after the existing service imports):

```dart
import 'services/location_reporter_service.dart';
```

Add registration after `Get.put(WsService());` (line 27):

```dart
Get.put(LocationReporterService());
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/main.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(location): register LocationReporterService in main.dart"
```

---

### Task 4: Clean up MapController

**Files:**
- Modify: `lib/modules/location/controller/map_controller.dart`

- [ ] **Step 1: Remove reporting logic, add stale refresh timer**

Replace the entire file with:

```dart
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
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/modules/location/controller/map_controller.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/location/controller/map_controller.dart
git commit -m "refactor(location): move GPS reporting to LocationReporterService, add stale refresh timer"
```

---

### Task 5: Update MemberMarker and member panel for stale display

**Files:**
- Modify: `lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Update `_MemberMarker` to accept and display stale state**

Replace the `_MemberMarker` class (lines 189-247) with:

```dart
/// 自定义成员标记组件
class _MemberMarker extends StatelessWidget {
  final String nickname;
  final String? avatarUrl;
  final bool isStale;
  final String timeAgoText;

  const _MemberMarker({
    required this.nickname,
    this.avatarUrl,
    this.isStale = false,
    this.timeAgoText = '',
  });

  @override
  Widget build(BuildContext context) {
    final color = isStale
        ? const Color(0xFF9E9E9E)
        : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isStale && timeAgoText.isNotEmpty)
                Text(
                  timeAgoText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: color),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
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
      ],
    );
  }
}
```

- [ ] **Step 2: Update the Marker construction to pass stale props**

In the `MarkerLayer` section (around line 53), update the `_MemberMarker` construction:

Replace:
```dart
child: _MemberMarker(
  nickname: m.nickname,
  avatarUrl: m.avatarUrl,
),
```

With:
```dart
child: _MemberMarker(
  nickname: m.nickname,
  avatarUrl: m.avatarUrl,
  isStale: m.isStale,
  timeAgoText: m.timeAgoText,
),
```

Also update `height: 50` to `height: 60` in the Marker to accommodate the time text.

- [ ] **Step 3: Update the bottom member panel to show stale info**

In `_buildMemberPanel`, inside the `Row` that shows member info, update the subtitle `Text` widget (the coordinates line) to also show time-ago when stale. Replace:

```dart
Text(
  '${member.latitude.toStringAsFixed(6)}, ${member.longitude.toStringAsFixed(6)}',
  style: TextStyle(
      fontSize: 12, color: Colors.grey.shade500),
),
```

With:

```dart
Text(
  member.isStale
      ? '${member.latitude.toStringAsFixed(6)}, ${member.longitude.toStringAsFixed(6)} · ${member.timeAgoText}'
      : '${member.latitude.toStringAsFixed(6)}, ${member.longitude.toStringAsFixed(6)}',
  style: TextStyle(
      fontSize: 12,
      color: member.isStale ? Colors.grey.shade400 : Colors.grey.shade500),
),
```

- [ ] **Step 4: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/location/view/map_view.dart
git commit -m "feat(location): show stale markers in grey with time-ago text"
```

---

### Task 6: Connect SettingsController and AuthService to LocationReporterService

**Files:**
- Modify: `lib/modules/settings/controller/settings_controller.dart`
- Modify: `lib/services/auth_service.dart`

- [ ] **Step 1: Update SettingsController to notify LocationReporterService on frequency change**

In `settings_controller.dart`, add import:

```dart
import '../../../services/location_reporter_service.dart';
```

Add field:

```dart
final LocationReporterService _reporter = Get.find<LocationReporterService>();
```

Update `setLocationFrequency`:

```dart
Future<void> setLocationFrequency(int seconds) async {
  locationFrequency.value = seconds;
  await _storage.write(AppConstants.locationFrequencyKey, seconds);
  _reporter.updateFrequency();
}
```

- [ ] **Step 2: Update AuthService to stop reporting on logout**

In `auth_service.dart`, add import:

```dart
import 'location_reporter_service.dart';
```

Update the `logout` method:

```dart
void logout() {
  Get.find<LocationReporterService>().stopReporting();
  _storage.clearAuth();
  currentUser.value = null;
  Get.offAllNamed('/login');
}
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd unii_app && flutter analyze lib/modules/settings/controller/settings_controller.dart lib/services/auth_service.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/settings/controller/settings_controller.dart lib/services/auth_service.dart
git commit -m "feat(location): connect settings and logout to LocationReporterService"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full project analysis**

Run: `cd unii_app && flutter analyze`
Expected: No errors. Warnings are acceptable.

- [ ] **Step 2: Verify build compiles**

Run: `cd unii_app && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL (or equivalent success message).

- [ ] **Step 3: Final commit (if any fixes needed)**

If analysis or build revealed issues, fix them and commit:
```bash
git add -A
git commit -m "fix(location): resolve analysis/build issues"
```
