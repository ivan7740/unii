# 前台定位上报 + Stale Marker 设计

> 日期: 2026-04-21
> 状态: 已批准

## 概述

接入真实 GPS，在前台按配置频率上报位置；App 进入后台时停止上报。队友位置超过 5 分钟未更新时，地图标记变灰并显示"X分钟前"。

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 后台行为 | 停止上报，显示最后位置 + 时间戳 | 简化实现，省电 |
| 过时标记样式 | 灰色圆点 + "X分钟前" | 直观且不影响地图可读性 |
| 过时阈值 | 5 分钟 | 适合标准户外活动节奏 |
| 架构 | 新建 LocationReporterService | 职责清晰，易于后续升级 |

## 架构

```
InitialBinding
    └── 注册 LocationReporterService（全局，App 级别）
            │
            ├── geolocator（读取 GPS）
            ├── Timer（按配置频率触发）
            └── 上报通道：WS 优先，断连降级 HTTP
                    │
                    ▼
            WsService / LocationService（已有，不改）

MapController
    └── 读取 activeTeamId，不再管 GPS 和上报
    └── 订阅 WS member_location，更新 memberLocations
    └── 60s Timer 刷新 memberLocations（触发 stale 状态更新）

MemberMarker widget
    └── recordedAt 与当前时间差 > 5分钟 → 灰色 + 时间标签
    └── ≤ 5分钟 → 正常彩色
```

## LocationReporterService 设计

**文件**: `lib/services/location_reporter_service.dart`

**职责**:
1. 请求并持有 GPS 权限
2. 按配置频率（3s/10s/30s）定时读取 GPS 坐标
3. WS 优先上报，断连时降级 HTTP
4. App 进入后台时暂停，回到前台时恢复

**接口**:

```dart
class LocationReporterService extends GetxService with WidgetsBindingObserver {
  final isReporting = false.obs;
  final lastPosition = Rxn<Position>();

  void startReporting();   // 前台激活后调用
  void stopReporting();    // 退出登录 / 进入后台
  void updateFrequency();  // 频率设置变更时刷新 Timer
}
```

**生命周期**:
- `didChangeAppLifecycleState(resumed)` → `startReporting()`
- `didChangeAppLifecycleState(paused/inactive)` → `stopReporting()`
- `AuthService.logout()` → `stopReporting()`

**权限处理**:
- 启动时检查权限，未授权则请求
- 永久拒绝时：`isReporting = false`，静默失败

## Stale Marker 显示

**判定规则**: `DateTime.now() - recordedAt > 5 minutes`

| 状态 | 圆点颜色 | 昵称标签 | 时间标签 |
|------|----------|----------|----------|
| 正常 | 品牌蓝色 | 白底黑字 | 无 |
| 过时 | 灰色 (#9E9E9E) | 灰底灰字 | 浅灰小字 |

**时间格式**:
- 5~59 分钟 → "X分钟前"
- 1~23 小时 → "X小时前"
- ≥ 24 小时 → "X天前"

**刷新机制**: MapController 中 60 秒 Timer 调用 `memberLocations.refresh()` 触发 UI 重建。

## 数据流

```
LocationReporterService
    │ geolocator.getCurrentPosition()
    │ ↓ (每 N 秒)
    ├─ WS connected? → ws.sendLocationUpdate(teamId, lat, lng, ...)
    │                      ↓ (服务端广播)
    │                   其他成员 WS 收到 member_location
    │                      ↓
    │                   MapController._onMemberLocation() → 更新 markers
    │
    └─ WS disconnected? → locationService.reportLocation(HTTP POST)
```

## 文件改动清单

**新增**:
| 文件 | 内容 |
|------|------|
| `lib/services/location_reporter_service.dart` | GPS 读取 + 定时上报 + 生命周期管理 |

**修改**:
| 文件 | 改动 |
|------|------|
| `map_controller.dart` | 删除 GPS/上报逻辑；新增 60s stale 刷新 Timer |
| `initial_binding.dart` | 注册 LocationReporterService |
| `location_settings_view.dart` | 切换频率后调用 updateFrequency() |
| `auth_service.dart` | logout() 中调用 stopReporting() |
| `map_view.dart` (MemberMarker) | stale 判定 + 灰色样式 + 时间标签 |

**不改动**:
- `ws_service.dart` — sendLocationUpdate() 已有
- `location_service.dart` — HTTP 上报已有
- `constants.dart` — 频率常量已有
- `pubspec.yaml` — geolocator 已有
