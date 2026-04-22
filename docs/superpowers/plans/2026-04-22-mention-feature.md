# @ 成员功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在团队聊天中支持 @ 成员：输入 `@` 弹出成员浮层，选择后插入 `@nickname`，后端解析发推送通知给被 @ 的在线用户。

**Architecture:** 前端 ChatController 检测输入中的 `@query` 并过滤成员，MentionOverlay 以 Stack 叠加在输入框上方；消息发送后，后端 `service::send_mention_notifications` 同时被 ws.rs（WS 路径）和 handler.rs（HTTP 路径）调用；NotificationService 全局监听 `mention_notification` WS 事件并触发本地推送。

**Tech Stack:** Flutter, GetX, Dart, Rust, Axum, sqlx, serde_json

---

## 文件结构

| 文件 | 变更 |
|------|------|
| `unii-server/src/message/service.rs` | 新增 `extract_mentions` + `send_mention_notifications` |
| `unii-server/src/message/ws.rs` | 调用 `send_mention_notifications` |
| `unii-server/src/message/handler.rs` | 调用 `send_mention_notifications` |
| `unii_app/lib/modules/message/widget/mention_overlay.dart` | 新增：成员浮层 widget |
| `unii_app/lib/modules/message/controller/chat_controller.dart` | 新增：成员加载、@ 检测、selectMention |
| `unii_app/lib/modules/message/view/chat_view.dart` | 修改：Stack 包裹输入区、onChanged |
| `unii_app/lib/modules/message/widget/message_bubble.dart` | 修改：@ 高亮 RichText |
| `unii_app/lib/services/notification_service.dart` | 新增：mention_notification 监听 |

---

### Task 1: 后端 service.rs — extract_mentions + send_mention_notifications

**Files:**
- Modify: `unii-server/src/message/service.rs`

- [ ] **Step 1: 在 service.rs 末尾添加 extract_mentions 函数和单元测试**

在 `unii-server/src/message/service.rs` 末尾，`get_team_messages` 函数后追加：

```rust
/// Extract unique @mentioned nicknames from message content.
/// Assumes frontend inserts "@nickname " (space-terminated).
pub fn extract_mentions(content: &str) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut names = Vec::new();
    for token in content.split_whitespace() {
        if let Some(name) = token.strip_prefix('@') {
            let name = name.trim_end_matches(|c: char| !c.is_alphanumeric() && c != '_');
            if !name.is_empty() && seen.insert(name.to_string()) {
                names.push(name.to_string());
            }
        }
    }
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_mentions_none() {
        assert!(extract_mentions("no mentions here").is_empty());
    }

    #[test]
    fn test_extract_mentions_single() {
        assert_eq!(extract_mentions("hello @Alice how are you"), vec!["Alice"]);
    }

    #[test]
    fn test_extract_mentions_multiple() {
        let mut names = extract_mentions("@Alice and @Bob please check");
        names.sort();
        assert_eq!(names, vec!["Alice", "Bob"]);
    }

    #[test]
    fn test_extract_mentions_dedup() {
        let names = extract_mentions("@Alice @Alice duplicate");
        assert_eq!(names.len(), 1);
        assert_eq!(names[0], "Alice");
    }

    #[test]
    fn test_extract_mentions_chinese() {
        assert_eq!(extract_mentions("@王小二 快跟上"), vec!["王小二"]);
    }

    #[test]
    fn test_extract_mentions_empty_content() {
        assert!(extract_mentions("").is_empty());
    }
}
```

- [ ] **Step 2: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test extract_mentions 2>&1
```

期望输出：`test message::service::tests::test_extract_mentions_* ... ok`（6 项全通过）

- [ ] **Step 3: 在 service.rs 中追加 send_mention_notifications 函数**

在 `extract_mentions` 函数之前（`#[cfg(test)]` 之前）插入：

```rust
/// Parse @mentions from content and send WS mention_notification to each online mentioned user.
/// Called after message is stored, for both WS and HTTP send paths.
pub async fn send_mention_notifications(
    db: &PgPool,
    ws_manager: &crate::ws::manager::WsManager,
    team_id: uuid::Uuid,
    sender_id: uuid::Uuid,
    sender_nickname: &str,
    message_id: i64,
    content: &str,
) {
    let nicknames = extract_mentions(content);
    if nicknames.is_empty() {
        return;
    }

    let team_name: String = match sqlx::query_scalar("SELECT name FROM teams WHERE id = $1")
        .bind(team_id)
        .fetch_one(db)
        .await
    {
        Ok(n) => n,
        Err(_) => return,
    };

    for nickname in &nicknames {
        let user_id: Option<uuid::Uuid> = sqlx::query_scalar(
            r#"
            SELECT u.id FROM users u
            JOIN team_members tm ON tm.user_id = u.id
            WHERE tm.team_id = $1 AND u.nickname = $2 AND u.id != $3
            "#,
        )
        .bind(team_id)
        .bind(nickname)
        .bind(sender_id)
        .fetch_optional(db)
        .await
        .unwrap_or(None);

        if let Some(uid) = user_id {
            let payload = serde_json::json!({
                "type": "mention_notification",
                "data": {
                    "team_id": team_id,
                    "team_name": team_name,
                    "sender_nickname": sender_nickname,
                    "content": content,
                    "message_id": message_id
                }
            });
            ws_manager.send_to_user(uid, &payload.to_string());
        }
    }
}
```

- [ ] **Step 4: 编译确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：编译成功，无 error。

- [ ] **Step 5: 运行全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过。

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/message/service.rs && git commit -m "feat(mention): add extract_mentions and send_mention_notifications to message service"
```

---

### Task 2: 后端 ws.rs — 调用 send_mention_notifications

**Files:**
- Modify: `unii-server/src/message/ws.rs`

- [ ] **Step 1: 在 ws.rs 顶部添加 service import**

在 `use crate::models::message::WsSendMessage;` 之后添加：

```rust
use crate::message::service;
```

- [ ] **Step 2: 在 broadcast 之后调用 send_mention_notifications**

找到 ws.rs 中以下代码段（位于文件末尾）：

```rust
    let exclude = if is_sos { None } else { Some(user_id) };
    state
        .ws_manager
        .broadcast_to_team(team_id, &broadcast.to_string(), exclude);
}
```

替换为：

```rust
    let exclude = if is_sos { None } else { Some(user_id) };
    state
        .ws_manager
        .broadcast_to_team(team_id, &broadcast.to_string(), exclude);

    service::send_mention_notifications(
        &state.db,
        &state.ws_manager,
        team_id,
        user_id,
        &nickname,
        saved_msg.id,
        &saved_msg.content,
    )
    .await;
}
```

- [ ] **Step 3: 编译确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：编译成功，无 error。

- [ ] **Step 4: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/message/ws.rs && git commit -m "feat(mention): call send_mention_notifications from WS message handler"
```

---

### Task 3: 后端 handler.rs — HTTP 路径调用 send_mention_notifications

**Files:**
- Modify: `unii-server/src/message/handler.rs`

- [ ] **Step 1: 在 handler.rs 顶部添加 service import（已有，确认即可）**

文件已有 `use crate::message::service;`，无需新增。

- [ ] **Step 2: 修改 send_message handler**

找到：

```rust
async fn send_message(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<SendMessageRequest>,
) -> AppResult<impl IntoResponse> {
    let resp = service::send_message(&state.db, auth.user_id, req).await?;
    Ok((StatusCode::CREATED, Json(resp)))
}
```

替换为：

```rust
async fn send_message(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<SendMessageRequest>,
) -> AppResult<impl IntoResponse> {
    let resp = service::send_message(&state.db, auth.user_id, req).await?;
    service::send_mention_notifications(
        &state.db,
        &state.ws_manager,
        resp.team_id,
        auth.user_id,
        &resp.sender_nickname,
        resp.id,
        &resp.content,
    )
    .await;
    Ok((StatusCode::CREATED, Json(resp)))
}
```

- [ ] **Step 3: 编译确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：编译成功，无 error。

- [ ] **Step 4: 运行全部后端测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过。

- [ ] **Step 5: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/message/handler.rs && git commit -m "feat(mention): call send_mention_notifications from HTTP message handler"
```

---

### Task 4: 前端 — MentionOverlay widget

**Files:**
- Create: `unii_app/lib/modules/message/widget/mention_overlay.dart`

- [ ] **Step 1: 创建 mention_overlay.dart**

创建文件 `unii_app/lib/modules/message/widget/mention_overlay.dart`：

```dart
import 'package:flutter/material.dart';
import '../../../models/team.dart';

class MentionOverlay extends StatelessWidget {
  final List<TeamMember> members;
  final void Function(TeamMember) onSelect;

  const MentionOverlay({
    super.key,
    required this.members,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final itemCount = members.length.clamp(1, 5);

    return Container(
      constraints: BoxConstraints(maxHeight: itemCount * 52.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return InkWell(
            onTap: () => onSelect(member),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      member.nickname.isNotEmpty ? member.nickname[0] : '?',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    member.nickname,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/widget/mention_overlay.dart 2>&1
```

期望：No issues found!

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/widget/mention_overlay.dart && git commit -m "feat(mention): add MentionOverlay widget"
```

---

### Task 5: 前端 ChatController — 成员加载与 @ 检测

**Files:**
- Modify: `unii_app/lib/modules/message/controller/chat_controller.dart`

- [ ] **Step 1: 添加 import 和字段**

在 `chat_controller.dart` 顶部 import 区，在 `import '../../../services/auth_service.dart';` 之前添加：

```dart
import '../../../models/team.dart';
import '../../../services/team_service.dart';
```

在 `ChatController` class 内，在 `final MessageCacheService _cache = Get.find<MessageCacheService>();` 之后添加：

```dart
  final TeamService _teamService = Get.find<TeamService>();

  final members = <TeamMember>[];
  final mentionQuery = ''.obs;
  final showMentionOverlay = false.obs;

  List<TeamMember> get filteredMembers {
    final query = mentionQuery.value.toLowerCase();
    if (query.isEmpty) return members;
    return members
        .where((m) => m.nickname.toLowerCase().contains(query))
        .toList();
  }

  String get currentNickname => _auth.currentUser.value?.nickname ?? '';
```

- [ ] **Step 2: 在 onInit 中加载成员**

找到 `onInit` 方法中 `_setupWsListeners();` 这一行，在其之前添加 `_loadMembers();`：

```dart
    _loadMembers();
    _setupWsListeners();
```

- [ ] **Step 3: 添加 _loadMembers、onTextChanged、selectMention 方法**

在 `_setupWsListeners` 方法之前添加：

```dart
  Future<void> _loadMembers() async {
    try {
      final detail = await _teamService.getTeamDetail(teamId);
      members.addAll(detail.members);
    } catch (_) {}
  }

  void onTextChanged(String text) {
    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) {
      mentionQuery.value = '';
      showMentionOverlay.value = false;
      return;
    }
    final afterAt = text.substring(lastAt + 1);
    if (afterAt.contains(' ')) {
      mentionQuery.value = '';
      showMentionOverlay.value = false;
    } else {
      mentionQuery.value = afterAt;
      showMentionOverlay.value = members.isNotEmpty;
    }
  }

  void selectMention(TeamMember member) {
    final text = textController.text;
    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) return;
    final newText = '${text.substring(0, lastAt)}@${member.nickname} ';
    textController.text = newText;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    mentionQuery.value = '';
    showMentionOverlay.value = false;
  }
```

- [ ] **Step 4: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/controller/chat_controller.dart 2>&1
```

期望：No issues found!

- [ ] **Step 5: 运行全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：全部测试通过（8 项）。

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/controller/chat_controller.dart && git commit -m "feat(mention): add member loading and @ detection to ChatController"
```

---

### Task 6: 前端 chat_view.dart — Stack 集成 MentionOverlay

**Files:**
- Modify: `unii_app/lib/modules/message/view/chat_view.dart`

- [ ] **Step 1: 添加 MentionOverlay import**

在 `chat_view.dart` 顶部，在 `import '../widget/quick_message_bar.dart';` 之后添加：

```dart
import '../widget/mention_overlay.dart';
```

- [ ] **Step 2: 将输入区包裹在 Stack 中，添加 MentionOverlay**

找到以下代码段（输入栏 Container）：

```dart
          // 输入栏
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
```

在该 Container 之前插入 MentionOverlay（在 Column 中，快捷消息栏之后）：

```dart
          // @ 成员浮层
          Obx(() {
            if (!controller.showMentionOverlay.value) {
              return const SizedBox.shrink();
            }
            return MentionOverlay(
              members: controller.filteredMembers,
              onSelect: controller.selectMention,
            );
          }),
```

- [ ] **Step 3: 为 TextField 添加 onChanged**

找到 chat_view.dart 中的 TextField，当前为：

```dart
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => controller.sendTextMessage(),
                    maxLines: null,
```

替换为：

```dart
                    textInputAction: TextInputAction.send,
                    onChanged: controller.onTextChanged,
                    onSubmitted: (_) => controller.sendTextMessage(),
                    maxLines: null,
```

- [ ] **Step 4: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/view/chat_view.dart 2>&1
```

期望：No issues found!

- [ ] **Step 5: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/view/chat_view.dart && git commit -m "feat(mention): integrate MentionOverlay into chat view"
```

---

### Task 7: 前端 message_bubble.dart — @ 高亮

**Files:**
- Modify: `unii_app/lib/modules/message/widget/message_bubble.dart`

- [ ] **Step 1: 为 MessageBubble 添加 currentNickname 参数**

找到 MessageBubble 的构造函数：

```dart
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });
```

替换为：

```dart
  final String currentNickname;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.currentNickname = '',
  });
```

注意：`final String currentNickname;` 这行需要添加到 class 字段区，在 `final bool isMe;` 之后。

完整字段区变为：

```dart
  final Message message;
  final bool isMe;
  final String currentNickname;
```

- [ ] **Step 2: 添加 _buildMessageContent 辅助方法**

在 `message_bubble.dart` 的 `_buildNormalBubble` 方法之前添加：

```dart
  Widget _buildMessageContent(String content, Color textColor) {
    final mention = '@$currentNickname';
    if (currentNickname.isEmpty || !content.contains(mention)) {
      return Text(content, style: TextStyle(color: textColor, fontSize: 15));
    }
    final parts = content.split(mention);
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(color: textColor, fontSize: 15),
        ));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: mention,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.yellow.withOpacity(0.35),
          ),
        ));
      }
    }
    return RichText(text: TextSpan(children: spans));
  }
```

- [ ] **Step 3: 在 _buildNormalBubble 中使用 _buildMessageContent**

找到 `_buildNormalBubble` 中的文字渲染部分：

```dart
                  child: Text(
                    isQuick ? '⚡ ${message.content}' : message.content,
                    style: TextStyle(
                      color: isMe
                          ? theme.colorScheme.onPrimary
                          : isQuick
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
```

替换为：

```dart
                  child: isQuick
                      ? Text(
                          '⚡ ${message.content}',
                          style: TextStyle(
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onTertiaryContainer,
                            fontSize: 15,
                          ),
                        )
                      : _buildMessageContent(
                          message.content,
                          isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
```

- [ ] **Step 4: 在 chat_view.dart 中为 MessageBubble 传入 currentNickname**

在 `chat_view.dart` 中，找到：

```dart
                  return MessageBubble(
                    message: message,
                    isMe: isMe,
                  );
```

替换为：

```dart
                  return MessageBubble(
                    message: message,
                    isMe: isMe,
                    currentNickname: controller.currentNickname,
                  );
```

- [ ] **Step 5: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/widget/message_bubble.dart lib/modules/message/view/chat_view.dart 2>&1
```

期望：No issues found!

- [ ] **Step 6: 运行全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：全部测试通过（8 项）。

- [ ] **Step 7: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/widget/message_bubble.dart unii_app/lib/modules/message/view/chat_view.dart && git commit -m "feat(mention): highlight @currentUser in message bubbles"
```

---

### Task 8: 前端 NotificationService — mention_notification 监听

**Files:**
- Modify: `unii_app/lib/services/notification_service.dart`

- [ ] **Step 1: 在 _setupWsListeners 中注册 mention_notification**

找到 `_setupWsListeners` 方法：

```dart
  void _setupWsListeners() {
    final ws = Get.find<WsService>();
    ws.on('new_message', _onNewMessage);
    ws.on('sos_alert', _onSosAlert);
  }
```

替换为：

```dart
  void _setupWsListeners() {
    final ws = Get.find<WsService>();
    ws.on('new_message', _onNewMessage);
    ws.on('sos_alert', _onSosAlert);
    ws.on('mention_notification', _onMentionNotification);
  }
```

- [ ] **Step 2: 添加 _onMentionNotification 方法**

在 `_onSosAlert` 方法之后添加：

```dart
  void _onMentionNotification(Map<String, dynamic> data) {
    final teamId = data['team_id'] as String?;
    final teamName = data['team_name'] as String? ?? '团队消息';
    final sender = data['sender_nickname'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    if (teamId == null) return;

    _showNotification(
      title: '$sender 在 $teamName 提到了你',
      body: content,
      channelId: _messageChannelId,
      channelName: _messageChannelName,
      payload: jsonEncode({'team_id': teamId, 'team_name': teamName}),
    );
  }
```

- [ ] **Step 3: 在 onClose 中取消注册**

找到 `onClose` 方法：

```dart
  @override
  void onClose() {
    final ws = Get.find<WsService>();
    ws.off('new_message', _onNewMessage);
    ws.off('sos_alert', _onSosAlert);
    super.onClose();
  }
```

替换为：

```dart
  @override
  void onClose() {
    final ws = Get.find<WsService>();
    ws.off('new_message', _onNewMessage);
    ws.off('sos_alert', _onSosAlert);
    ws.off('mention_notification', _onMentionNotification);
    super.onClose();
  }
```

- [ ] **Step 4: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/services/notification_service.dart 2>&1
```

期望：No issues found!

- [ ] **Step 5: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/services/notification_service.dart && git commit -m "feat(mention): handle mention_notification WS event in NotificationService"
```

---

### Task 9: 最终验证

**Files:** (无代码修改)

- [ ] **Step 1: 全项目 Flutter 分析**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze 2>&1
```

期望：No issues found!

- [ ] **Step 2: 全部 Flutter 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：全部测试通过（8 项）。

- [ ] **Step 3: 全部后端测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过。

- [ ] **Step 4: 更新 todolist.md**

将 `todolist.md` 中以下两行标记为完成：

```
- [ ] **[F]** @ 成员功能：输入 @ 弹出成员选择列表
- [ ] **[B]** 后端 @ 消息处理：解析 @ 内容，对被 @ 用户发专门通知
```

改为：

```
- [x] **[F]** @ 成员功能：输入 @ 弹出成员选择列表
- [x] **[B]** 后端 @ 消息处理：解析 @ 内容，对被 @ 用户发专门通知
```

- [ ] **Step 5: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add todolist.md && git commit -m "chore: mark @ mention feature as done"
```
