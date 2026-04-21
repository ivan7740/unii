# Map Style Switching Design

**Date:** 2026-04-21  
**Status:** Approved

## Goal

Let users switch the map tile layer between Standard, Satellite, and Terrain styles. The selected style persists across app restarts via Hive.

## Architecture

`MapController` gains a reactive `mapStyle` variable (String: `'standard'` / `'satellite'` / `'terrain'`). On `onInit`, it reads the last-used style from Hive (`mapStyleKey` already defined in `AppConstants`). `setMapStyle()` updates the variable and writes to Hive. `MapView` wraps `TileLayer` in `Obx` to rebuild when the style changes, and adds a 3-button column overlay in the top-left corner of the map.

## File Changes

| File | Change |
|------|--------|
| `lib/modules/location/controller/map_controller.dart` | Add `mapStyle` RxString, `setMapStyle()` method, load from Hive in `onInit` |
| `lib/modules/location/view/map_view.dart` | Wrap TileLayer in Obx, add `_buildStyleButtons()` overlay |

## Tile URL Mapping

| Style key | Tile URL | Provider |
|-----------|----------|----------|
| `standard` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | OpenStreetMap |
| `satellite` | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | Esri World Imagery |
| `terrain` | `https://a.tile.opentopomap.org/{z}/{x}/{y}.png` | OpenTopoMap |

Note: All three providers are free and require no API key.

## MapController Changes

### New field
```dart
final mapStyle = 'standard'.obs;
```

### onInit addition
```dart
final savedStyle = _storage.read<String>(AppConstants.mapStyleKey);
if (savedStyle != null) mapStyle.value = savedStyle;
```

### New method
```dart
void setMapStyle(String style) {
  mapStyle.value = style;
  _storage.write(AppConstants.mapStyleKey, style);
}
```

## MapView Changes

### TileLayer — wrap in Obx
Replace the static `TileLayer(urlTemplate: '...')` with:

```dart
Obx(() {
  final urls = {
    'standard': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'terrain': 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
  };
  return TileLayer(
    urlTemplate: urls[controller.mapStyle.value] ?? urls['standard']!,
    userAgentPackageName: 'com.unii.app',
  );
}),
```

### Style button overlay
Add inside the `Stack`, positioned top-left:

```dart
Positioned(
  top: 48,
  left: 12,
  child: _buildStyleButtons(),
),
```

### `_buildStyleButtons()` widget
```dart
Widget _buildStyleButtons() {
  return Obx(() {
    final styles = [
      ('standard', Icons.map, '标准'),
      ('satellite', Icons.satellite_alt, '卫星'),
      ('terrain', Icons.terrain, '地形'),
    ];
    return Container(
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
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          );
        }).toList(),
      ),
    );
  });
}
```

## Persistence

Uses existing `AppConstants.mapStyleKey = 'map_style'` and `StorageService.write/read`. No new constants needed.

## Error Handling

- If Hive returns an unrecognized style string (e.g., from a future version), `urls[style]` will return null. The `!` force-unwrap will throw. Guard with: `urls[controller.mapStyle.value] ?? urls['standard']!` to fall back gracefully.

## Testing

Add a unit test verifying `setMapStyle` updates `mapStyle.value` and the URL map covers all 3 keys with non-empty strings.
