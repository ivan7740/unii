# Online Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show real-time online/offline status (green dot) on map markers and bottom member panel, powered by WS events.

**Architecture:** Backend sends `team_online_members` (initial list) when a user joins a team channel. Frontend MapController listens for `member_online` and `team_online_members` WS events, updating `MemberLocation.isOnline`. MemberMarker renders a green dot when online.

**Tech Stack:** Rust/Axum backend (ws/handler.rs), Flutter/GetX frontend, existing WsManager and WsService

---

## File Structure

| File | Role |
|------|------|
| `unii-server/src/ws/handler.rs` | Add team_online_members response in join_team_channel |
| `unii_app/lib/modules/location/controller/map_controller.dart` | Listen to member_online + team_online_members events |
| `unii_app/lib/modules/location/view/map_view.dart` | Add isOnline green dot to MemberMarker + bottom panel |

---

### Task 1: Backend — send online members list on join_team_channel

**Files:**
- Modify: `unii-server/src/ws/handler.rs:115-129`

- [ ] **Step 1: Add team_online_members response**

In `unii-server/src/ws/handler.rs`, find the `"join_team_channel"` match arm. After the existing `broadcast_to_team` call and the `tracing::debug!` line, add:

```rust
// Send current online members to the joining user
let online_ids = state.ws_manager.get_online_members(team_id);
let online_msg = serde_json::json!({
    "type": "team_online_members",
    "data": { "team_id": team_id, "user_ids": online_ids }
});
state.ws_manager.send_to_user(user_id, &online_msg.to_string());
```

The full `join_team_channel` arm should now be:

```rust
"join_team_channel" => {
    if let Some(team_id) =
        data["team_id"]
            .as_str()
            .and_then(|s| Uuid::parse_str(s).ok())
    {
        state.ws_manager.subscribe_team(user_id, team_id);
        let msg = serde_json::json!({
            "type": "member_online",
            "data": { "user_id": user_id, "online": true }
        });
        state
            .ws_manager
            .broadcast_to_team(team_id, &msg.to_string(), Some(user_id));
        tracing::debug!("User {} joined team channel {}", user_id, team_id);

        // Send current online members to the joining user
        let online_ids = state.ws_manager.get_online_members(team_id);
        let online_msg = serde_json::json!({
            "type": "team_online_members",
            "data": { "team_id": team_id, "user_ids": online_ids }
        });
        state.ws_manager.send_to_user(user_id, &online_msg.to_string());
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo check`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/ws/handler.rs && git commit -m "feat(ws): send team_online_members on join_team_channel"
```

---

### Task 2: Frontend — MapController listens for online status events

**Files:**
- Modify: `unii_app/lib/modules/location/controller/map_controller.dart`

- [ ] **Step 1: Register WS listeners in onInit**

In `onInit()`, after the line `_ws.on('member_location', _onMemberLocation);`, add:

```dart
_ws.on('member_online', _onMemberOnline);
_ws.on('team_online_members', _onTeamOnlineMembers);
```

- [ ] **Step 2: Unregister listeners in onClose**

In `onClose()`, after `_ws.off('member_location', _onMemberLocation);`, add:

```dart
_ws.off('member_online', _onMemberOnline);
_ws.off('team_online_members', _onTeamOnlineMembers);
```

- [ ] **Step 3: Add handler methods**

Add these two methods to the class (after `_onMemberLocation`):

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

- [ ] **Step 4: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/controller/map_controller.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/controller/map_controller.dart && git commit -m "feat(location): listen for member_online and team_online_members WS events"
```

---

### Task 3: Frontend — MemberMarker and bottom panel green dot

**Files:**
- Modify: `unii_app/lib/modules/location/view/map_view.dart`

- [ ] **Step 1: Add isOnline parameter to _MemberMarker**

In the `_MemberMarker` class, add a new field after `timeAgoText`:

```dart
final bool isOnline;
```

Update the constructor to include it:

```dart
const _MemberMarker({
  required this.nickname,
  this.avatarUrl,
  this.isStale = false,
  this.timeAgoText = '',
  this.isOnline = false,
});
```

- [ ] **Step 2: Add green online indicator to the marker**

In the `_MemberMarker.build` method, wrap the bottom `Container` (the 12x12 circle dot) in a `Stack` to overlay a green indicator:

Replace the bottom circle Container:
```dart
Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(
    color: color,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 4,
      ),
    ],
  ),
),
```

With:
```dart
SizedBox(
  width: 16,
  height: 16,
  child: Stack(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      if (isOnline)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
    ],
  ),
),
```

- [ ] **Step 3: Pass isOnline in the Marker construction**

In the `MarkerLayer` section, update the `_MemberMarker` construction to pass `isOnline`:

```dart
child: _MemberMarker(
  nickname: m.nickname,
  avatarUrl: m.avatarUrl,
  isStale: m.isStale,
  timeAgoText: m.timeAgoText,
  isOnline: m.isOnline,
),
```

- [ ] **Step 4: Add green dot to bottom member panel**

In `_buildMemberPanel`, replace the `CircleAvatar` for each member with a `Stack` that overlays a green dot:

Replace:
```dart
CircleAvatar(
  radius: 16,
  child: Text(
    member.nickname.isNotEmpty ? member.nickname[0] : '?',
    style: const TextStyle(fontSize: 14),
  ),
),
```

With:
```dart
Stack(
  children: [
    CircleAvatar(
      radius: 16,
      child: Text(
        member.nickname.isNotEmpty ? member.nickname[0] : '?',
        style: const TextStyle(fontSize: 14),
      ),
    ),
    if (member.isOnline)
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
  ],
),
```

- [ ] **Step 5: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/map_view.dart`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/map_view.dart && git commit -m "feat(location): show green online indicator on map markers and member panel"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run backend check**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo check`
Expected: No errors.

- [ ] **Step 2: Run frontend analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No errors.

- [ ] **Step 3: Fix any issues if needed**

If errors found, fix and commit:
```bash
git add -A && git commit -m "fix(online-status): resolve build issues"
```
