# @ 成员功能设计文档

**日期：** 2026-04-22  
**范围：** Phase 7 消息增强 — @ 成员功能  
**状态：** 已审批

---

## 概述

在团队聊天中支持 @ 成员：输入 `@` 时弹出成员选择浮层，选择后插入 `@nickname`，消息发送后后端解析 @ 内容并向被 @ 用户推送 WS `mention_notification`，前端收到后触发本地通知。

---

## 技术选型

**方案 A（采用）：后端解析 @**  
前端发送普通文本消息，后端在入库后扫描内容提取昵称，查询匹配用户并推送 WS 通知。逻辑集中、前端改动小，适合小型团队（昵称冲突概率极低）。

---

## Section 1：前端 @ 检测与成员浮层

### ChatController 扩展

| 新增字段 | 类型 | 说明 |
|---------|------|------|
| `members` | `List<TeamMember>` | onInit 时加载，调用 `getTeamDetail(teamId).members` |
| `mentionQuery` | `RxString` | 光标前匹配 `@\w*` 时更新，否则为空字符串 |
| `showMentionOverlay` | `RxBool` | `mentionQuery` 非空时为 true |
| `filteredMembers` | `List<TeamMember>` | 按 `mentionQuery` 过滤 `members`（昵称包含匹配） |

新增方法：

- `onTextChanged(String text)`：在 `TextField.onChanged` 中调用，检测光标前是否有 `@query` 模式，更新 `mentionQuery`
- `selectMention(TeamMember member)`：将当前 `@query` 替换为 `@nickname `（含尾部空格），关闭浮层，光标移到末尾

### MentionOverlay widget（新文件）

`lib/modules/message/widget/mention_overlay.dart`

- 接收 `filteredMembers`，`onSelect` 回调
- 每项显示成员昵称
- 最多显示 5 条，超出可滚动
- 位于输入框上方，通过 Stack 叠加

### chat_view.dart 改动

- 输入区外层用 `Stack` 包裹
- `Obx` 监听 `showMentionOverlay`，条件渲染 `MentionOverlay`
- `TextField.onChanged` 改为调用 `controller.onTextChanged(value)`

---

## Section 2：后端 @ 解析与 WS 通知

### 解析位置

`message/service.rs` → `send_message` 方法，消息入库后、广播 `new_message` 后执行。

### 解析逻辑

1. 正则扫描消息内容：`@([\w一-龥]+)`（支持中英文昵称）
2. 提取所有匹配昵称，去重
3. SQL 查询：在 `team_members JOIN users` 中按昵称匹配，限定 `team_id`
4. 排除发送者本人

### 新增 WS 事件

**事件名：** `mention_notification`

```json
{
  "type": "mention_notification",
  "data": {
    "team_id": "uuid",
    "team_name": "string",
    "sender_nickname": "string",
    "content": "string",
    "message_id": 123
  }
}
```

推送方式：`WsManager::send_to_user(user_id, payload)`，逐一推送给被 @ 用户。被 @ 用户不在线则静默忽略（无离线消息队列）。

---

## Section 3：前端通知处理

### 全局监听注册

在 `WsService.onInit` 或 `initial_binding.dart` 中注册，不依赖聊天页是否打开：

```dart
_ws.on('mention_notification', (data) {
  NotificationService.show(
    title: '${data['sender_nickname']} 提到了你',
    body: data['content'] as String,
    payload: data['team_id'] as String,
  );
});
```

通知点击跳转到对应团队聊天页（复用现有通知点击逻辑）。

### 气泡高亮（低成本优化）

`message_bubble.dart` 中用 `RichText` 渲染消息内容：检测是否含当前用户的 `@nickname`，若有则高亮该段文字（粗体或品牌色）。

---

## 文件变更汇总

| 文件 | 变更类型 |
|------|---------|
| `lib/modules/message/controller/chat_controller.dart` | 修改：添加成员加载、@ 检测、mention 选择 |
| `lib/modules/message/widget/mention_overlay.dart` | 新增：成员浮层 widget |
| `lib/modules/message/view/chat_view.dart` | 修改：Stack 包裹输入区，集成浮层 |
| `lib/modules/message/widget/message_bubble.dart` | 修改：@ 高亮渲染 |
| `lib/services/ws_service.dart` | 修改：注册 mention_notification 全局监听 |
| `unii-server/src/message/service.rs` | 修改：入库后解析 @ 并推送通知 |

---

## 边界情况

- @ 后无匹配成员：浮层显示为空，不弹出
- 昵称含空格：不支持（昵称注册时已限制）
- 多个 @ 同一人：只发一条通知（去重）
- 被 @ 用户不在线：静默忽略
- WS 断连走 HTTP 发送：HTTP 发送后后端同样执行 @ 解析逻辑
