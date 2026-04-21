# Member Distance Display Design

**Date:** 2026-04-21  
**Status:** Approved

## Goal

Show the distance from the user's own GPS position to each team member in the bottom member panel of the map view.

## Architecture

`MapController` gains a `distanceTo(MemberLocation member)` method that reads `_reporter.lastPosition` (already a `Rxn<Position>` in the injected `LocationReporterService`) and calls `Geolocator.distanceBetween()` to compute meters. It returns a formatted string or `null` when the user's own position is unknown. `MapView` renders the formatted distance on the right side of each member row in the bottom panel.

## File Changes

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `distanceTo(MemberLocation member)` method |
| `lib/modules/location/view/map_view.dart` | Add distance text to each member row in bottom panel |

## MapController Changes

### New method

```dart
String? distanceTo(MemberLocation member) {
  final pos = _reporter.lastPosition.value;
  if (pos == null) return null;
  final meters = Geolocator.distanceBetween(
    pos.latitude,
    pos.longitude,
    member.latitude,
    member.longitude,
  );
  if (meters < 100) return '< 100 m';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
```

**Dependencies:** `geolocator` is already in `pubspec.yaml`. `_reporter` is already injected in `MapController`.

## MapView Changes

In `_buildMemberPanel`'s `itemBuilder`, inside each member row, add the distance text after the chevron icon:

```dart
Obx(() {
  final dist = controller.distanceTo(member);
  if (dist == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      dist,
      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
    ),
  );
}),
```

The `Obx` wrapper ensures the distance updates reactively when `_reporter.lastPosition` changes. The result is stored in a local variable (`dist`) to avoid calling `distanceTo` twice.

## Distance Formatting Rules

| Condition | Format | Example |
|-----------|--------|---------|
| meters < 100 | `'< 100 m'` | `< 100 m` |
| 100 ≤ meters < 1000 | `'${meters.round()} m'` | `350 m` |
| meters ≥ 1000 | `'${(meters / 1000).toStringAsFixed(1)} km'` | `1.2 km` |

## Error Handling

- `_reporter.lastPosition.value == null` → return `null` → UI shows nothing (SizedBox.shrink)
- `Geolocator.distanceBetween` does not throw for valid lat/lon inputs
- Member coordinates from the server are always valid (validated at API layer)

## Testing

Add a unit test for `distanceTo` formatting logic by extracting the formatting as a static helper and testing the three distance tiers plus the null case.
