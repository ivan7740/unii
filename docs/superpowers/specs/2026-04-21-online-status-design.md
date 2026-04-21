# 在线状态显示设计

> 日期: 2026-04-21
> 状态: 已批准

## 概述

在地图 marker、底部成员面板和团队成员列表中显示实时在线/离线状态（绿色圆点）。后端在用户加入团队频道时返回当前在线成员列表，前端通过 WS 事件实时更新状态。

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 获取初始在线状态 | join_team_channel 时后端回发在线列表 | 利用已有 WS 基础，无需新 REST 端点 |
| 在线指示样式 | 绿色圆点（8px）+ 离线不显示 | 简洁，不增加视觉噪音 |
| 显示位置 | 地图 marker + 底部面板 + 团队详情成员列表 | todolist 要求两处都显示 |

## 后端改动

**文件**: `unii-server/src/ws/handler.rs`

在 `join_team_channel` 处理分支中，subscribe 并广播之后，向加入者回发当前在线成员列表：

```rust
let online_ids = state.ws_manager.get_online_members(team_id);
let online_msg = serde_json::json!({
    "type": "team_online_members",
    "data": { "team_id": team_id, "user_ids": online_ids }
});
state.ws_manager.send_to_user(user_id, &online_msg.to_string());
```

WS 消息格式：
- `member_online`: `{"type": "member_online", "data": {"user_id": "...", "online": true/false}}` (已有)
- `team_online_members`: `{"type": "team_online_members", "data": {"team_id": "...", "user_ids": ["id1", "id2"]}}` (新增)

## 前端改动

### MapController

监听两个新事件：

```dart
_ws.on('member_online', _onMemberOnline);
_ws.on('team_online_members', _onTeamOnlineMembers);
```

处理逻辑：

```dart
void _onMemberOnline(Map<String, dynamic> data) {
  final userId = data['user_id'] as String?;
  final online = data['online'] as bool? ?? false;
  if (userId == null) return;
  final index = memberLocations.indexWhere((m) => m.userId == userId);
  if (index >= 0) {
    memberLocations[index] = memberLocations[index].copyWith(isOnline: online);
  }
}

void _onTeamOnlineMembers(Map<String, dynamic> data) {
  final userIds = (data['user_ids'] as List?)?.cast<String>() ?? [];
  for (var i = 0; i < memberLocations.length; i++) {
    final isOnline = userIds.contains(memberLocations[i].userId);
    if (memberLocations[i].isOnline != isOnline) {
      memberLocations[i] = memberLocations[i].copyWith(isOnline: isOnline);
    }
  }
}
```

### MemberMarker (map_view.dart)

增加 `isOnline` 参数。在圆点旁显示绿色在线指示：

- 在线：圆点外层加绿色描边（或旁边加小绿点）
- 离线 + 未过时：正常显示（品牌蓝）
- 离线 + 过时：灰色（已有 stale 逻辑）

具体样式：在底部定位圆点右下角叠加一个 8px 绿色圆，仅当 `isOnline == true` 时显示。

### 底部成员面板 (map_view.dart)

成员头像 `CircleAvatar` 右下角加 `Positioned` 绿色圆点（与 marker 同理）。

### 团队详情成员列表

暂不在团队详情页显示在线状态。原因：TeamDetailController 若临时 join/leave channel 会导致后端广播错误的离线状态给其他成员。在线状态仅显示在地图页面（活跃团队已订阅频道）。如果后续需要，可通过添加 REST 端点解决。

## 数据流

```
用户A join_team_channel
    ↓ 后端
    ├── broadcast member_online(user_id=A, online=true) → 团队其他人
    └── send team_online_members(user_ids=[B,C]) → 用户A

用户A 前端收到 team_online_members
    ↓
    MapController: 标记 B、C 为 isOnline=true

其他人前端收到 member_online(A, true)
    ↓
    MapController: 标记 A 为 isOnline=true
```

## 文件改动清单

**后端**:
| 文件 | 改动 |
|------|------|
| `src/ws/handler.rs` | join_team_channel 中回发 team_online_members |

**前端**:
| 文件 | 改动 |
|------|------|
| `lib/modules/location/controller/map_controller.dart` | 监听 member_online + team_online_members |
| `lib/modules/location/view/map_view.dart` | MemberMarker 加 isOnline 绿点 + 底部面板加绿点 |

**不改动**:
- `ws_service.dart` — 多 listener 机制已支持
- `models/location.dart` — MemberLocation.isOnline + copyWith 已有
- `ws/manager.rs` — get_online_members() 已有
