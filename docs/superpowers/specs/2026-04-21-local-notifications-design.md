# 本地通知（SOS + 新消息）设计

> 日期: 2026-04-21
> 状态: 已批准

## 概述

集成 flutter_local_notifications，在用户不在对应团队聊天页时弹出本地通知。SOS 使用高优先级通知（持续振动 + 系统提示音），普通消息使用默认通知。点击通知导航到对应团队聊天页。

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 普通消息通知触发条件 | 后台 + 前台但不在该团队聊天页 | 户外协调场景消息时效性强 |
| SOS 通知方式 | 高优先级（振动+声音+锁屏） | 紧急求助必须立即引起注意 |
| 架构 | 新建 NotificationService | 职责单一，不污染现有代码 |

## 架构

```
main.dart
    └── 注册 NotificationService（全局，WsService 之后）

NotificationService (GetxService)
    ├── 初始化 flutter_local_notifications plugin
    ├── 监听 WS: 'new_message' + 'sos_alert'
    ├── 判断是否弹通知（检查当前路由是否为该团队 /chat）
    ├── 弹本地通知（SOS 高优先级 / 普通默认）
    └── 处理通知点击 → Get.toNamed('/chat', arguments: {...})

ChatController（不改动）
    └── 继续保留 SOS 弹窗（前台在该聊天页时弹 Dialog）
```

## NotificationService 设计

**文件**: `lib/services/notification_service.dart`

**职责**:
1. 初始化 flutter_local_notifications（Android + iOS）
2. 全局监听 WS 事件 (new_message, sos_alert)
3. 判断是否需要弹通知（_shouldNotify）
4. 按类型选择通知频道并显示通知
5. 处理通知点击 → 导航

**接口**:

```dart
class NotificationService extends GetxService {
  Future<NotificationService> init() async { ... }
}
```

**Android 通知频道**:
- `sos_channel` — 名称"SOS紧急通知"，importance max，vibration pattern [0, 500, 200, 500, 200, 500]
- `message_channel` — 名称"消息通知"，importance default

**iOS 设置**:
- requestAlertPermission: true
- requestBadgePermission: true
- requestSoundPermission: true

**是否弹通知判定**:

```dart
bool _shouldNotify(String teamId) {
  if (Get.currentRoute == '/chat') {
    try {
      final chatCtrl = Get.find<ChatController>();
      if (chatCtrl.teamId == teamId) return false;
    } catch (_) {}
  }
  return true;
}
```

**通知点击处理**:

```dart
void _onNotificationTap(NotificationResponse response) {
  final payload = jsonDecode(response.payload ?? '{}');
  final teamId = payload['team_id'];
  final teamName = payload['team_name'];
  if (teamId != null) {
    Get.toNamed('/chat', arguments: {'team_id': teamId, 'team_name': teamName});
  }
}
```

**注册位置**: `main.dart` 中 `await Get.putAsync(() => NotificationService().init())`，在 WsService 之后。

## 通知内容格式

| 类型 | 标题 | 内容 |
|------|------|------|
| SOS | "🆘 SOS 紧急求助" | "{nickname}: {content}" |
| 普通消息 | "{teamName}" | "{nickname}: {content}" |

## 数据流

```
WS 服务端推送 'new_message' / 'sos_alert'
    ↓
WsService._onMessage → 分发给所有 listeners
    ↓
┌─ NotificationService._onNewMessage / _onSosAlert
│     ├── _shouldNotify(teamId) == false → 不弹（在当前聊天页）
│     └── _shouldNotify(teamId) == true → 弹本地通知
│           └── 用户点击 → _onNotificationTap → Get.toNamed('/chat')
│
└─ ChatController._onNewMessage / _onSosAlert（已有，不改）
      └── 在当前聊天页 → 插入消息 / 弹 SOS Dialog
```

## 文件改动清单

**新增**:
| 文件 | 内容 |
|------|------|
| `lib/services/notification_service.dart` | 通知初始化 + WS 监听 + 弹通知 + 点击导航 |

**修改**:
| 文件 | 改动 |
|------|------|
| `lib/main.dart` | 导入并注册 NotificationService |

**不改动**:
- `chat_controller.dart` — SOS Dialog 保留
- `ws_service.dart` — 多 listener 机制已支持
- `pubspec.yaml` — flutter_local_notifications 已有
- `AndroidManifest.xml` — POST_NOTIFICATIONS 权限已有
