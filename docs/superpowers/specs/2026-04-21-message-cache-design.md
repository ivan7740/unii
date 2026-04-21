# Message Local Cache Design

**Date:** 2026-04-21  
**Status:** Approved

## Goal

Cache team chat messages to Hive so users can read recent history offline, and the chat view shows content immediately on open without waiting for the API.

## Architecture

New `MessageCacheService` (GetxService) wraps a Hive `Box<String>` and exposes three operations: load, save, and prepend. `ChatController` reads from cache on init (instant display), then fetches from API and saves the result. WS new messages and sent messages are prepended to the cache immediately.

## File Changes

| File | Change |
|------|--------|
| `lib/services/message_cache_service.dart` | NEW: Hive Box<String> wrapper |
| `lib/main.dart` | Add `Get.put(MessageCacheService())` |
| `lib/modules/message/controller/chat_controller.dart` | Read cache on init, write cache on load/receive/send |

## MessageCacheService

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

  List<Message> loadMessages(String teamId) {
    final raw = _box.get(teamId);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void saveMessages(String teamId, List<Message> messages) {
    final trimmed = messages.take(_maxMessages).toList();
    _box.put(teamId, jsonEncode(trimmed.map((m) => m.toJson()).toList()));
  }

  void prependMessage(String teamId, Message message) {
    final existing = loadMessages(teamId);
    final updated = [message, ...existing].take(_maxMessages).toList();
    _box.put(teamId, jsonEncode(updated.map((m) => m.toJson()).toList()));
  }
}
```

**Notes:**
- `Message.fromJson` and `Message.toJson` already exist in the model — no model changes needed
- Cache is keyed by `teamId` (String)
- `take(_maxMessages)` keeps at most 100 messages; assumes messages are ordered newest-first (matching `ChatController.messages` observable)

## main.dart Change

Add after `Get.put(MessageService());`:

```dart
await Get.putAsync(() => MessageCacheService().init());
```

**Ordering constraint:** `StorageService` must be registered first (it calls `Hive.initFlutter()`). `MessageCacheService` calls `Hive.openBox()` and must come after. Current `main.dart` registers `StorageService` first, so inserting after `MessageService` is safe.

## ChatController Changes

### onInit — load cache before API

After initialising listeners, add:

```dart
// Show cached messages immediately
final cached = _cache.loadMessages(teamId);
if (cached.isNotEmpty) messages.value = cached;
// Then fetch from API (existing loadHistory call)
loadHistory();
```

### After loadHistory completes — save to cache

After `messages.value = result;`:

```dart
_cache.saveMessages(teamId, messages);
```

### On WS new_message received — prepend to cache

After `messages.insert(0, msg);`:

```dart
_cache.prependMessage(teamId, msg);
```

### On send success — prepend to cache

After the confirmed message is inserted into `messages`:

```dart
_cache.prependMessage(teamId, confirmedMsg);
```

## Cache Format

```
Hive Box<String> name: "message_cache"
key:   teamId (String)
value: JSON array string, e.g. '[{"id":"...","content":"..."}]'
       newest message first, max 100 entries
```

## Error Handling

- `loadMessages`: catches any JSON decode error and returns empty list — ChatController falls back to API load
- `saveMessages` / `prependMessage`: Hive write failures are silent (Hive itself handles disk errors gracefully)
- If Hive box fails to open: `init()` throws, `Get.putAsync` propagates the error to `main()` — same behaviour as `StorageService` failure

## Testing

Add unit tests for `MessageCacheService.loadMessages` (empty box returns empty list, corrupt JSON returns empty list) and verify `saveMessages` trims to 100 entries.
