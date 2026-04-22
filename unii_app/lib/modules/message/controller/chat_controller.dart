import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/message.dart';
import '../../../models/team.dart';
import '../../../services/auth_service.dart';
import '../../../services/message_cache_service.dart';
import '../../../services/message_service.dart';
import '../../../services/team_service.dart';
import '../../../services/ws_service.dart';

class ChatController extends GetxController {
  final MessageService _messageService = Get.find<MessageService>();
  final WsService _ws = Get.find<WsService>();
  final AuthService _auth = Get.find<AuthService>();
  final MessageCacheService _cache = Get.find<MessageCacheService>();
  final TeamService _teamService = Get.find<TeamService>();

  final members = <TeamMember>[];
  final mentionQuery = Rxn<String>();

  List<TeamMember> get filteredMembers {
    final query = mentionQuery.value;
    if (query == null) return [];
    if (query.isEmpty) return members;
    return members
        .where((m) => m.nickname.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  String get currentNickname => _auth.currentUser.value?.nickname ?? '';

  final messages = <Message>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final showQuickBar = false.obs;

  final textController = TextEditingController();
  final scrollController = ScrollController();

  late String teamId;
  late String teamName;

  String get currentUserId => _auth.currentUser.value?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    teamId = args['team_id'] as String;
    teamName = args['team_name'] as String;

    _loadMembers();
    _setupWsListeners();

    // Show cached messages immediately, then refresh from API
    final cached = _cache.loadMessages(teamId);
    if (cached.isNotEmpty) messages.value = cached;
    loadMessages();

    scrollController.addListener(_onScroll);
  }

  Future<void> _loadMembers() async {
    try {
      final detail = await _teamService.getTeamDetail(teamId);
      members.addAll(detail.members);
    } catch (_) {}
  }

  void onTextChanged(String text) {
    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) {
      mentionQuery.value = null;
      return;
    }
    final afterAt = text.substring(lastAt + 1);
    if (afterAt.contains(' ')) {
      mentionQuery.value = null;
    } else {
      mentionQuery.value = afterAt;
    }
  }

  void selectMention(String nickname) {
    final text = textController.text;
    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) return;
    final newText = '${text.substring(0, lastAt)}@$nickname ';
    textController.text = newText;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    mentionQuery.value = null;
  }

  void _setupWsListeners() {
    _ws.on('new_message', _onNewMessage);
    _ws.on('sos_alert', _onSosAlert);
  }

  void _onNewMessage(Map<String, dynamic> data) {
    if (data['team_id'] != teamId) return;
    final msg = Message.fromJson(data);
    messages.insert(0, msg);
    _cache.prependMessage(teamId, msg);
  }

  void _onSosAlert(Map<String, dynamic> data) {
    if (data['team_id'] != teamId) return;
    final msg = Message.fromJson(data);
    messages.insert(0, msg);
    _cache.prependMessage(teamId, msg);

    // SOS 弹窗提示
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('紧急求助'),
          ],
        ),
        content: Text('${msg.senderNickname} 发出了 SOS 求助：\n\n${msg.content}'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('知道了'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> loadMessages() async {
    isLoading.value = true;
    try {
      final result = await _messageService.getTeamMessages(teamId);
      messages.value = result;
      hasMore.value = result.length >= 50;
      _cache.saveMessages(teamId, messages);
    } catch (e) {
      Get.snackbar('错误', '加载消息失败');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || messages.isEmpty) return;
    isLoadingMore.value = true;
    try {
      final oldestId = messages.last.id;
      final result = await _messageService.getTeamMessages(
        teamId,
        beforeId: oldestId,
      );
      messages.addAll(result);
      hasMore.value = result.length >= 50;
      _cache.saveMessages(teamId, messages);
    } catch (e) {
      // 静默失败
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  void sendTextMessage() {
    final content = textController.text.trim();
    if (content.isEmpty) return;
    textController.clear();
    _sendMessage(content, 'text');
  }

  void sendQuickMessage(String content) {
    _sendMessage(content, 'quick');
    showQuickBar.value = false;
  }

  void sendSosMessage() {
    _sendMessage('SOS 紧急求助！', 'sos');
  }

  void _sendMessage(String content, String msgType) {
    if (_ws.status.value == ConnectionStatus.connected) {
      _ws.send('send_message', {
        'team_id': teamId,
        'content': content,
        'msg_type': msgType,
      });
      // 本地立即添加消息（乐观更新）
      final now = DateTime.now();
      final tempMsg = Message(
        id: -(now.millisecondsSinceEpoch),
        teamId: teamId,
        senderId: currentUserId,
        senderNickname: _auth.currentUser.value?.nickname ?? 'Me',
        content: content,
        msgType: msgType,
        isSos: msgType == 'sos',
        createdAt: now,
      );
      messages.insert(0, tempMsg);
    } else {
      // WS 断连，走 HTTP
      _sendMessageHttp(content, msgType);
    }
  }

  Future<void> _sendMessageHttp(String content, String msgType) async {
    try {
      final msg = await _messageService.sendMessage(
        teamId: teamId,
        content: content,
        msgType: msgType,
      );
      messages.insert(0, msg);
      _cache.prependMessage(teamId, msg);
    } catch (e) {
      Get.snackbar('发送失败', '消息发送失败，请重试');
    }
  }

  void toggleQuickBar() {
    showQuickBar.value = !showQuickBar.value;
  }

  @override
  void onClose() {
    _ws.off('new_message', _onNewMessage);
    _ws.off('sos_alert', _onSosAlert);
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
