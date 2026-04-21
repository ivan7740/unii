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
