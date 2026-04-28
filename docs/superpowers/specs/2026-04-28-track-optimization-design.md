# 轨迹查询优化设计规格

**目标：** 在 unii_app 前端添加时间范围选择器和 Douglas-Peucker 轨迹简化，提升轨迹页的使用体验和地图渲染性能。后端 API 已有 `start`/`end` 时间过滤支持，本次不改动后端。

---

## 架构

### 文件变更

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `lib/utils/track_utils.dart` | 纯 Dart RDP 算法，`simplify(points, toleranceMeters)` |
| 修改 | `lib/modules/location/controller/track_controller.dart` | 新增时间范围状态、精度状态、派生简化点集 |
| 修改 | `lib/modules/location/view/track_view.dart` | 顶部时间 Sheet + 控制面板精度滑块 |

### 数据流

```
用户选择时间范围
    → TrackController.changePreset() / setCustomRange()
    → loadTrack() 调用 LocationService.getUserTrack(start, end)
    → trackPoints 更新
    → simplifiedPoints 自动重新计算（watch precisionIndex + trackPoints）
    → 地图 Polyline 使用 simplifiedPoints
    → 时间轴 Slider 仍使用原始 trackPoints（保留回放精度）
```

---

## TrackUtils（新文件）

**文件：** `lib/utils/track_utils.dart`

```dart
import 'dart:math';
import '../models/location.dart';

class TrackUtils {
  // 容差级别（米）：高/中/低
  static const tolerances = [5.0, 15.0, 50.0];

  // 不足此阈值时不简化
  static const _minPointsToSimplify = 100;

  /// Ramer–Douglas–Peucker 简化
  /// 使用经纬度欧氏近似（1° ≈ 111_000m），精度对户外轨迹足够
  static List<TrackPoint> simplify(List<TrackPoint> points, double toleranceMeters) {
    if (points.length < _minPointsToSimplify) return points;
    final epsilon = toleranceMeters / 111000.0; // 转为度数
    return _rdp(points, epsilon);
  }

  static List<TrackPoint> _rdp(List<TrackPoint> points, double epsilon) {
    if (points.length < 3) return List.of(points);
    double maxDist = 0;
    int index = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDist(points[i], points.first, points.last);
      if (d > maxDist) { maxDist = d; index = i; }
    }
    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, index + 1), epsilon);
      final right = _rdp(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  // 返回点 p 到线段 (start, end) 的垂直距离（度数单位，与 epsilon 量纲一致）
  static double _perpendicularDist(TrackPoint p, TrackPoint start, TrackPoint end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      // 线段退化为点
      final ex = p.longitude - start.longitude;
      final ey = p.latitude - start.latitude;
      return sqrt(ex * ex + ey * ey);
    }
    final t = ((p.longitude - start.longitude) * dx +
                (p.latitude - start.latitude) * dy) / lenSq;
    final tc = t.clamp(0.0, 1.0);
    final px = start.longitude + tc * dx;
    final py = start.latitude + tc * dy;
    final ex = p.longitude - px;
    final ey = p.latitude - py;
    return sqrt(ex * ex + ey * ey); // 线性距离，与 epsilon 量纲一致
  }
}
```

---

## TrackController（变更）

**新增状态字段：**

```dart
// 时间范围
final selectedPreset = 'today'.obs; // 'today' | 'yesterday' | '3days' | 'custom'
final customStart = Rxn<DateTime>();
final customEnd = Rxn<DateTime>();

// D-P 精度：0=高(5m) 1=中(15m) 2=低(50m)
final precisionIndex = 1.obs;

// 派生：简化后的显示点集（供地图使用）
final simplifiedPoints = <TrackPoint>[].obs;
```

**新增方法：**

```dart
void changePreset(String preset) {
  selectedPreset.value = preset;
  loadTrack();
}

void setCustomRange(DateTime start, DateTime end) {
  customStart.value = start;
  customEnd.value = end;
  selectedPreset.value = 'custom';
  loadTrack();
}

void changePrecision(int index) {
  precisionIndex.value = index;
  _applySimplification();
}

void _applySimplification() {
  simplifiedPoints.value = TrackUtils.simplify(
    trackPoints,
    TrackUtils.tolerances[precisionIndex.value],
  );
}
```

**修改 `loadTrack()`：** 根据 `selectedPreset` 计算 `start`/`end`，加载完成后调用 `_applySimplification()`。

**Preset → 时间范围映射：**

| Preset | start | end |
|--------|-------|-----|
| today | 今天 00:00:00 | 现在 |
| yesterday | 昨天 00:00:00 | 昨天 23:59:59 |
| 3days | 3 天前 00:00:00 | 现在 |
| custom | `customStart.value` | `customEnd.value` |

---

## TrackView（变更）

### AppBar

- `title`: `'${controller.nickname} 的轨迹'`（不变）
- `bottom`: `PreferredSize` 显示时间摘要小字（如 "今天 · 04-28 00:00 – 14:35 · 原始 342 点 → 显示 87 点"）
- `actions`: 日历图标按钮，点击调用 `_showTimeRangeSheet(context)`

### 时间范围 Bottom Sheet（`_showTimeRangeSheet`）

```
┌──────────────────────────────┐
│  选择时间范围                 │
│  [今天] [昨天] [近3天] [自定义] │  ← ChoiceChip 行
│                              │
│  （选"自定义"时展开：）         │
│  开始日期: [日期选择器]         │
│  结束日期: [日期选择器]         │
│                              │
│              [确认]           │
└──────────────────────────────┘
```

快捷选项直接关闭 Sheet 并触发加载；"自定义"展开日期选择器，点"确认"后调用 `setCustomRange()`。

### 控制面板（`_buildControlPanel`）新增行

在现有播放栏下方新增：

```
精度  [高] ——●—— [低]     原始 342 点 → 显示 87 点
```

- `Slider` 三档（0/1/2），拖动时调用 `controller.changePrecision(v.toInt())`
- 右侧文字实时显示点数变化

---

## 完成标准

1. 快捷时间选项（今天/昨天/近3天）切换后重新加载轨迹
2. 自定义时间选择器能正确传参
3. 精度滑块实时更新地图 Polyline，时间轴 Slider 不受影响
4. 点数少于 100 时不触发简化（直接显示原始数据）
5. `flutter analyze` 无 error
