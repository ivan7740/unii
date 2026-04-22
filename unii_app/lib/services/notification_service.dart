import 'dart:convert';
import 'dart:typed_data';

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
    ws.on('mention_notification', _onMentionNotification);
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
    ws.off('mention_notification', _onMentionNotification);
    super.onClose();
  }
}
