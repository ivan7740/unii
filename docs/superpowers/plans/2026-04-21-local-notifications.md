# Local Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show local notifications for SOS alerts (high priority) and new messages (default) when the user is not in the relevant team's chat page. Tapping a notification navigates to that team's chat.

**Architecture:** New `NotificationService` (GetxService) initializes flutter_local_notifications, listens globally to WS events, checks current route to decide whether to notify, and handles notification taps for navigation.

**Tech Stack:** Flutter, GetX, flutter_local_notifications (already in pubspec), WsService (existing)

---

## File Structure

| File | Role |
|------|------|
| `lib/services/notification_service.dart` | NEW: Initialize notifications, listen to WS, show notifications, handle taps |
| `lib/main.dart` | Register NotificationService after WsService |

---

### Task 1: Create NotificationService

**Files:**
- Create: `lib/services/notification_service.dart`

- [ ] **Step 1: Create the service file**

```dart
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../modules/message/controller/chat_controller.dart';
import '../modules/message/controller/message_list_controller.dart';
import 'ws_service.dart';

class NotificationService extends GetxService {
  late FlutterLocalNotificationsPlugin _plugin;
  int _notificationId = 0;

  static const _sosChannelId = 'sos_channel';
  static const _sosChannelName = 'SOS紧急通知';
  static const _messageChannelId = 'message_channel';
  static const _messageChannelName = '消息通知';

  Future<NotificationService> init() async {
    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _sosChannelId,
          _sosChannelName,
          description: 'SOS 紧急求助通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _messageChannelId,
          _messageChannelName,
          description: '团队消息通知',
          importance: Importance.defaultImportance,
        ),
      );
    }

    _setupWsListeners();
    return this;
  }

  void _setupWsListeners() {
    final ws = Get.find<WsService>();
    ws.on('new_message', _onNewMessage);
    ws.on('sos_alert', _onSosAlert);
  }

  void _onNewMessage(Map<String, dynamic> data) {
    final teamId = data['team_id'] as String?;
    if (teamId == null) return;
    if (!_shouldNotify(teamId)) return;

    final nickname = data['sender_nickname'] ?? '';
    final content = data['content'] ?? '';
    final teamName = _resolveTeamName(teamId);

    _showNotification(
      title: teamName,
      body: '$nickname: $content',
      channelId: _messageChannelId,
      channelName: _messageChannelName,
      payload: jsonEncode({'team_id': teamId, 'team_name': teamName}),
    );
  }

  void _onSosAlert(Map<String, dynamic> data) {
    final teamId = data['team_id'] as String?;
    if (teamId == null) return;
    if (!_shouldNotify(teamId)) return;

    final nickname = data['sender_nickname'] ?? '';
    final content = data['content'] ?? '';
    final teamName = _resolveTeamName(teamId);

    _showNotification(
      title: '\u{1F198} SOS 紧急求助',
      body: '$nickname: $content',
      channelId: _sosChannelId,
      channelName: _sosChannelName,
      importance: Importance.max,
      priority: Priority.high,
      payload: jsonEncode({'team_id': teamId, 'team_name': teamName}),
    );
  }

  bool _shouldNotify(String teamId) {
    if (Get.currentRoute == '/chat') {
      try {
        final chatCtrl = Get.find<ChatController>();
        if (chatCtrl.teamId == teamId) return false;
      } catch (_) {}
    }
    return true;
  }

  String _resolveTeamName(String teamId) {
    try {
      final ctrl = Get.find<MessageListController>();
      final team = ctrl.teams.firstWhereOrNull((t) => t.id == teamId);
      if (team != null) return team.name;
    } catch (_) {}
    return '团队消息';
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _notificationId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!);
      final teamId = data['team_id'] as String?;
      final teamName = data['team_name'] as String? ?? '团队消息';
      if (teamId != null) {
        Get.toNamed('/chat',
            arguments: {'team_id': teamId, 'team_name': teamName});
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    final ws = Get.find<WsService>();
    ws.off('new_message', _onNewMessage);
    ws.off('sos_alert', _onSosAlert);
    super.onClose();
  }
}
```

- [ ] **Step 2: Add required import for Int64List**

The file uses `Int64List` for vibration pattern. Add this import at the top of the file:

```dart
import 'dart:typed_data';
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/services/notification_service.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat(notifications): create NotificationService with SOS and message notifications"
```

---

### Task 2: Register NotificationService in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

Add after existing service imports:

```dart
import 'services/notification_service.dart';
```

- [ ] **Step 2: Register the service**

Add after `Get.put(LocationReporterService());` (which is after WsService):

```dart
await Get.putAsync(() => NotificationService().init());
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/main.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(notifications): register NotificationService in main.dart"
```

---

### Task 3: Final verification

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No errors.

- [ ] **Step 2: Verify build compiles**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Fix any issues if needed**

If analysis or build revealed issues, fix and commit:
```bash
git add -A
git commit -m "fix(notifications): resolve analysis/build issues"
```
