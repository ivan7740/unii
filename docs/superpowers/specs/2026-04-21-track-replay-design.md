# 轨迹回放设计

> 日期: 2026-04-21
> 状态: 已批准

## 概述

新增轨迹回放页面，显示成员的历史轨迹 Polyline，通过时间滑块可查看任意时间点的位置，支持播放/暂停自动推进。纯前端实现，后端无改动。

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 回放交互 | 时间滑块 + 播放按钮 | 最实用：快速定位任意时间点 |
| 后端轨迹简化 | 不做（YAGNI）| 5000 点上限足够，flutter_map 性能无问题 |
| 时间范围 | 默认当天 00:00 到当前时间 | 简化交互，后续按需加日期选择器 |
| 入口 | 地图底部面板成员 onTap | 自然的操作路径 |

## 架构

```
地图页底部成员面板 → 点击成员 → /track 页面
    参数: userId, teamId, nickname

TrackController
    ├── loadTrack() → LocationService.getUserTrack()
    ├── trackPoints (RxList<TrackPoint>)
    ├── currentIndex (RxInt)
    ├── isPlaying (RxBool)
    └── playback Timer (200ms 间隔)

TrackView
    ├── FlutterMap + Polyline + 当前位置 Marker
    ├── AppBar("{nickname} 的轨迹")
    └── 底部控制面板 (播放/暂停 + Slider + 时间标签)
```

## TrackController 设计

**文件**: `lib/modules/location/controller/track_controller.dart`

**接口**:
```dart
class TrackController extends GetxController {
  final trackPoints = <TrackPoint>[].obs;
  final currentIndex = 0.obs;
  final isPlaying = false.obs;
  final isLoading = false.obs;

  late String userId;
  late String teamId;
  late String nickname;

  TrackPoint? get currentPoint =>
      trackPoints.isNotEmpty ? trackPoints[currentIndex.value] : null;

  void play();       // 启动 200ms Timer，每步 currentIndex++
  void pause();      // 取消 Timer
  void seekTo(int index);  // 滑块跳转
}
```

**时间范围**: 默认当天 00:00 至当前时间。

**回放逻辑**:
- `play()`: 启动 Timer.periodic(200ms)，每次 currentIndex++，到末尾自动 pause()
- `pause()`: 取消 Timer，isPlaying = false
- `seekTo(int)`: 暂停播放，直接设置 currentIndex

**导航参数**:
```dart
Get.toNamed('/track', arguments: {
  'user_id': userId,
  'team_id': teamId,
  'nickname': nickname,
});
```

## TrackView 设计

**文件**: `lib/modules/location/view/track_view.dart`

**布局**:
```
┌─────────────────────────┐
│ AppBar: "nickname 的轨迹" │
├─────────────────────────┤
│                         │
│   FlutterMap            │
│   ├─ Polyline (蓝色线)  │
│   └─ Marker (红色当前点) │
│                         │
├─────────────────────────┤
│ ▶/⏸  ═══●═══════  14:30 │
│ 09:00             17:30  │
└─────────────────────────┘
```

**Polyline**: 蓝色 (#2196F3)，宽度 3px，连接所有 trackPoints

**当前位置 Marker**: 红色实心圆 (14px)，白色描边 2px，位置由 currentIndex 决定

**控制面板**:
- IconButton: 播放 (Icons.play_arrow) / 暂停 (Icons.pause)
- Slider: min 0, max trackPoints.length - 1, value currentIndex
- 当前时间文本: currentPoint.recordedAt 格式化为 "HH:mm:ss"
- 起止时间标签: 首尾 trackPoint 的时间

**空状态**: "暂无轨迹数据" + 图标

**地图适配**: 加载完成后 fitBounds 到轨迹 bounding box

## 文件改动清单

**新增**:
| 文件 | 内容 |
|------|------|
| `lib/modules/location/controller/track_controller.dart` | 轨迹数据加载 + 回放逻辑 |
| `lib/modules/location/view/track_view.dart` | 地图 + Polyline + 滑块 + 控制面板 |
| `lib/modules/location/binding/track_binding.dart` | 注册 TrackController |

**修改**:
| 文件 | 改动 |
|------|------|
| `lib/app/routes/app_pages.dart` | 添加 /track GetPage + binding |
| `lib/modules/location/view/map_view.dart` | 底部面板成员 onTap 导航到 /track |

**不改动**:
- `location_service.dart` — getUserTrack() 已有
- `models/location.dart` — TrackPoint 已有
- 后端 — 无改动
