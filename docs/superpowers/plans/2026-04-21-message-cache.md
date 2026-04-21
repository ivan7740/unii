# Message Local Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cache team chat messages in Hive so the chat view shows history immediately on open and works offline.

**Architecture:** New `MessageCacheService` wraps a `Hive Box<String>` keyed by `teamId`. `ChatController` loads from cache before hitting the API (instant display), saves after successful API loads, and prepends new WS/HTTP messages to the cache.

**Tech Stack:** Flutter, GetX, Hive (already in pubspec), dart:convert

---

## File Structure

| File | Change |
|------|--------|
| `lib/services/message_cache_service.dart` | NEW: Hive Box<String> wrapper with load/save/prepend |
| `lib/main.dart` | Add `MessageCacheService` registration |
| `lib/modules/message/controller/chat_controller.dart` | Read cache on init, write cache on load/receive/send |
| `test/widget_test.dart` | Add `parseMessages` unit tests |

---

### Task 1: Create MessageCacheService with unit tests

**Files:**
- Create: `lib/services/message_cache_service.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/widget_test.dart` inside `main()`, after existing tests:

```dart
import 'package:unii_app/services/message_cache_service.dart';
```

Add at the top with other imports. Then add tests:

```dart
test('MessageCacheService.parseMessages returns empty list for empty string', () {
  expect(MessageCacheService.parseMessages(''), isEmpty);
});

test('MessageCacheService.parseMessages returns empty list for corrupt JSON', () {
  expect(MessageCacheService.parseMessages('not-json'), isEmpty);
  expect(MessageCacheService.parseMessages('{invalid}'), isEmpty);
});

test('MessageCacheService.parseMessages returns empty list for empty array', () {
  expect(MessageCacheService.parseMessages('[]'), isEmpty);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: FAIL — `MessageCacheService` not found.

- [ ] **Step 3: Create MessageCacheService**

Create `lib/services/message_cache_service.dart`:

```dart
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/message.dart';

class MessageCacheService extends GetxService {
  static const _boxName = 'message_cache';
  static const _maxMessages = 100;
  late Box<String> _box;

  Future<MessageCacheService> init() async {
    _box = await Hive.openBox<String>(_boxName);
    return this;
  }

  /// Parse raw JSON string from Hive into a list of Messages.
  /// Returns empty list on any error.
  static List<Message> parseMessages(String raw) {
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Message> loadMessages(String teamId) {
    final raw = _box.get(teamId) ?? '';
    return parseMessages(raw);
  }

  void saveMessages(String teamId, List<Message> messages) {
    final trimmed = messages.take(_maxMessages).toList();
    _box.put(
      teamId,
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  void prependMessage(String teamId, Message message) {
    final existing = loadMessages(teamId);
    final updated = [message, ...existing].take(_maxMessages).toList();
    _box.put(
      teamId,
      jsonEncode(updated.map((m) => m.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widget_test.dart`
Expected: All 8 tests pass.

- [ ] **Step 5: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/services/message_cache_service.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/services/message_cache_service.dart unii_app/test/widget_test.dart && git commit -m "feat(messages): create MessageCacheService with Hive-backed message cache"
```

---

### Task 2: Register MessageCacheService in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

In `lib/main.dart`, add after the line `import 'services/message_service.dart';`:

```dart
import 'services/message_cache_service.dart';
```

- [ ] **Step 2: Register the service**

After `Get.put(MessageService());` (line 27), add:

```dart
  await Get.putAsync(() => MessageCacheService().init());
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/main.dart`
Expected: No issues found.

- [ ] **Step 4: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/main.dart && git commit -m "feat(messages): register MessageCacheService in main.dart"
```

---

### Task 3: Integrate cache reads/writes into ChatController

**Files:**
- Modify: `lib/modules/message/controller/chat_controller.dart`

- [ ] **Step 1: Add import and inject MessageCacheService**

In `lib/modules/message/controller/chat_controller.dart`, add after existing imports:

```dart
import '../../../services/message_cache_service.dart';
```

Inside `ChatController` class, add after `final AuthService _auth = Get.find<AuthService>();`:

```dart
  final MessageCacheService _cache = Get.find<MessageCacheService>();
```

- [ ] **Step 2: Load cache before API call in onInit**

Find `onInit`:
```dart
    _setupWsListeners();
    loadMessages();
```

Replace with:
```dart
    _setupWsListeners();

    // Show cached messages immediately, then refresh from API
    final cached = _cache.loadMessages(teamId);
    if (cached.isNotEmpty) messages.value = cached;
    loadMessages();
```

- [ ] **Step 3: Save cache after loadMessages succeeds**

Find in `loadMessages()`:
```dart
      final result = await _messageService.getTeamMessages(teamId);
      messages.value = result;
      hasMore.value = result.length >= 50;
```

Replace with:
```dart
      final result = await _messageService.getTeamMessages(teamId);
      messages.value = result;
      hasMore.value = result.length >= 50;
      _cache.saveMessages(teamId, messages);
```

- [ ] **Step 4: Save cache after loadMore succeeds**

Find in `loadMore()`:
```dart
      messages.addAll(result);
      hasMore.value = result.length >= 50;
```

Replace with:
```dart
      messages.addAll(result);
      hasMore.value = result.length >= 50;
      _cache.saveMessages(teamId, messages);
```

- [ ] **Step 5: Prepend to cache on WS new_message**

Find `_onNewMessage`:
```dart
    final msg = Message.fromJson(data);
    messages.insert(0, msg);
```

Replace with:
```dart
    final msg = Message.fromJson(data);
    messages.insert(0, msg);
    _cache.prependMessage(teamId, msg);
```

- [ ] **Step 6: Prepend to cache on WS sos_alert**

Find `_onSosAlert`:
```dart
    final msg = Message.fromJson(data);
    messages.insert(0, msg);

    // SOS 弹窗提示
```

Replace with:
```dart
    final msg = Message.fromJson(data);
    messages.insert(0, msg);
    _cache.prependMessage(teamId, msg);

    // SOS 弹窗提示
```

- [ ] **Step 7: Prepend to cache on HTTP send success**

Find `_sendMessageHttp`:
```dart
      final msg = await _messageService.sendMessage(
        teamId: teamId,
        content: content,
        msgType: msgType,
      );
      messages.insert(0, msg);
```

Replace with:
```dart
      final msg = await _messageService.sendMessage(
        teamId: teamId,
        content: content,
        msgType: msgType,
      );
      messages.insert(0, msg);
      _cache.prependMessage(teamId, msg);
```

- [ ] **Step 8: Verify no analysis errors**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/controller/chat_controller.dart`
Expected: No issues found.

- [ ] **Step 9: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 8 tests pass.

- [ ] **Step 10: Commit**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/controller/chat_controller.dart && git commit -m "feat(messages): integrate MessageCacheService into ChatController for offline cache"
```

---

### Task 4: Final verification

**Files:** (none)

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run all tests**

Run: `cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test`
Expected: 8 tests pass.

- [ ] **Step 3: Fix any issues if found**

If errors: fix and commit:
```bash
cd /Users/mac/rust_flutter_app/study_dw && git add -A && git commit -m "fix(messages): resolve message cache analysis issues"
```
