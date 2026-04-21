# Background Location Reporting Design

**Date:** 2026-04-21  
**Status:** Approved

## Goal

Keep reporting the user's location to the team while the app is in the background, using reduced frequency to conserve battery.

## Approach

Extend the existing `LocationReporterService` (which already implements `WidgetsBindingObserver`) to switch to a low-frequency background mode instead of stopping on app pause. No new packages required — geolocator (already in pubspec) supports background location via platform-specific settings.

## Architecture

Two modes:

| Mode | Trigger | Frequency | Platform behavior |
|------|---------|-----------|-------------------|
| Foreground | `AppLifecycleState.resumed` | User-selected (3 / 10 / 30s) | Normal GPS |
| Background | `AppLifecycleState.paused` | Fixed 60s | Android: foreground service notification; iOS: `always` permission |

## File Changes

### 1. `lib/utils/constants.dart`

Add one constant:

```dart
static const int frequencyBackground = 60;
```

### 2. `lib/services/location_reporter_service.dart`

**New field:**
```dart
bool _isInBackground = false;
```

**`didChangeAppLifecycleState` updated:**
- `paused` / `inactive` → call `_enterBackground()` (was: `stopReporting()`)
- `resumed` → call `_exitBackground()` (was: `startReporting()`)

**New methods:**
```dart
void _enterBackground() {
  if (!isReporting.value) return;
  _isInBackground = true;
  _reportTimer?.cancel();
  _reportTimer = Timer.periodic(
    const Duration(seconds: AppConstants.frequencyBackground),
    (_) => _reportCurrentLocation(),
  );
}

void _exitBackground() {
  _isInBackground = false;
  if (!isReporting.value) {
    startReporting();
  } else {
    updateFrequency(); // restore user-selected interval
  }
}
```

**`_checkAndRequestPermission()` updated:**  
Request `LocationPermission.always` (not `whileInUse`) so iOS allows background access.

**`_reportCurrentLocation()` updated:**  
When `_isInBackground == true`, pass `AndroidSettings` with `foregroundNotificationConfig` to `getCurrentPosition()`:

```dart
final locationSettings = _isInBackground
    ? AndroidSettings(
        accuracy: LocationAccuracy.medium,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'UNII 位置共享',
          notificationText: '正在后台共享位置',
          enableWakeLock: true,
        ),
      )
    : const LocationSettings(accuracy: LocationAccuracy.high);
```

iOS does not require special settings beyond the `always` permission — geolocator handles it.

## Permission Flow

1. On first `startReporting()`, request `LocationPermission.always`
2. If user grants only `whileInUse`, foreground reporting works but background stops when OS suspends the app (graceful degradation)
3. iOS shows system prompt: "Allow UNII to use your location → Always"

## Battery Impact

- Foreground: unchanged (user-selected frequency)
- Background: 1 GPS fix per 60s, medium accuracy → minimal battery use
- Android: foreground service notification keeps process alive but uses negligible CPU between fixes

## Error Handling

- If GPS fix fails in background: skip cycle, try next interval (existing behavior)
- If WS disconnected in background: fall back to HTTP (existing behavior)
- No crash recovery needed — timer restarts on `_exitBackground()`
