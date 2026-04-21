# Off-Screen Member Direction Arrows Design

**Date:** 2026-04-21  
**Status:** Approved

## Goal

Show small directional arrows at the map edges pointing toward team members who are currently off-screen, with a truncated nickname label so users know who is off-screen.

## Architecture

Add flutter_map's `MapController` (`fm.MapController`, aliased to avoid naming conflict with the GetX `MapController`) to `FlutterMap`. The GetX `MapController` holds an instance of `fm.MapController` as `fmController` and a `Rxn<fm.MapCamera>` as `mapCamera`. The `onMapEvent` callback updates `mapCamera` reactively on every pan/zoom. `MapView` adds an `IgnorePointer`-wrapped `_buildOffScreenArrows()` overlay at the top of the `Stack` that uses `Obx` + `LayoutBuilder` to compute and position rotated arrow widgets at the map edges.

## File Changes

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `fmController`, `mapCamera`, `onMapEvent()` |
| `lib/modules/location/view/map_view.dart` | Wire up `mapController`/`onMapEvent`, add arrow overlay, add `_buildOffScreenArrows()` + `_clampToEdge()` |

## flutter_map API Reference (v7.0.2)

- `fm.MapController` — imported as `import 'package:flutter_map/flutter_map.dart' as fm`
- `fm.MapCamera.latLngToScreenPoint(LatLng)` → `Point<double>` — position relative to map widget top-left
- `fm.MapCamera.nonRotatedSize` → `Point<double>` — map widget pixel dimensions
- `fm.MapEvent.camera` → `fm.MapCamera` — camera state at event time

## MapController (GetX) Changes

```dart
import 'package:flutter_map/flutter_map.dart' as fm;
import 'dart:math' as math;

// New fields (add after existing fields)
final fmController = fm.MapController();
final mapCamera = Rxn<fm.MapCamera>();

// New method
void onMapEvent(fm.MapEvent event) {
  mapCamera.value = event.camera;
}
```

No disposal needed — `fm.MapController` has no `dispose()` method.

## MapView Changes

### FlutterMap widget — add mapController and onMapEvent

Replace:
```dart
FlutterMap(
  options: MapOptions(
    initialCenter: ...,
    initialZoom: 14,
  ),
```

With:
```dart
FlutterMap(
  mapController: controller.fmController,
  options: MapOptions(
    initialCenter: ...,
    initialZoom: 14,
    onMapEvent: controller.onMapEvent,
  ),
```

### Stack — add arrow overlay (LAST child, on top of everything)

Add inside the `Stack`'s `children` list, after the refresh FAB `Positioned`:

```dart
            // Off-screen member arrows
            Positioned.fill(
              child: IgnorePointer(
                child: _buildOffScreenArrows(),
              ),
            ),
```

### `_buildOffScreenArrows()` method

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

### `_clampToEdge()` helper (static)

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

## Required Imports in map_view.dart

```dart
import 'dart:math' as math;
import 'package:latlong2/latlong.dart'; // already present
```

## Arrow Visual

- Icon: `Icons.navigation` (filled triangle), size 20, blue
- Label: up to 4 chars of nickname + `..` if longer, 9px, blue bold
- Rotation: `atan2(dy, dx) + π/2` so the triangle tip points toward the member

## Error Handling

- `mapCamera == null`: overlay returns `SizedBox.shrink()` (no arrows until first map event)
- Member with `dx == 0 && dy == 0`: edge case where member is exactly at screen center — `scale` stays `infinity`, `clamp` keeps point within bounds — safe
- No members off-screen: returns `SizedBox.shrink()`

## Testing

`_clampToEdge` is a private static helper — correctness is verified visually (pan the map so members go off-screen). No unit test needed. Run `flutter analyze` + `flutter test` (5 existing tests) to verify no regressions.
