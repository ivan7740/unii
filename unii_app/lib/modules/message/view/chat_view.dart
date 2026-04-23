import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/empty_state.dart';
import '../controller/chat_controller.dart';
import '../widget/message_bubble.dart';
import '../widget/quick_message_bar.dart';
import '../widget/mention_overlay.dart';

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.teamName),
        actions: [
          // SOS 按钮
          _SosButton(onSos: controller.sendSosMessage),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.messages.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.forum_outlined,
                  message: '还没有消息',
                  hint: '发一条消息打个招呼吧',
                );
              }

              return ListView.builder(
                controller: controller.scrollController,
                reverse: true,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: controller.messages.length +
                    (controller.hasMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == controller.messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final message = controller.messages[index];
                  final isMe = message.senderId == controller.currentUserId;

                  return MessageBubble(
                    message: message,
                    isMe: isMe,
                    currentNickname: controller.currentNickname,
                  );
                },
              );
            }),
          ),

          // 快捷消息栏
          Obx(() => controller.showQuickBar.value
              ? QuickMessageBar(onSelect: controller.sendQuickMessage)
              : const SizedBox.shrink()),

          // @ 成员浮层
          const MentionOverlay(),

          // 输入栏
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // 快捷消息切换
                IconButton(
                  icon: Obx(() => Icon(
                        controller.showQuickBar.value
                            ? Icons.keyboard
                            : Icons.bolt,
                        color: theme.colorScheme.primary,
                      )),
                  onPressed: controller.toggleQuickBar,
                  tooltip: '快捷消息',
                ),
                // 文字输入
                Expanded(
                  child: TextField(
                    controller: controller.textController,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onChanged: controller.onTextChanged,
                    onSubmitted: (_) => controller.sendTextMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 4),
                // 发送按钮
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: controller.sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SOS 按钮 — 长按触发
class _SosButton extends StatelessWidget {
  final VoidCallback onSos;

  const _SosButton({required this.onSos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: () {
          // 确认对话框
          Get.dialog(
            AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.sos, color: Colors.red),
                  SizedBox(width: 8),
                  Text('发送 SOS 求助'),
                ],
              ),
              content: const Text('确认发送 SOS 紧急求助消息？\n团队所有成员都会收到提醒。'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Get.back();
                    onSos();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('发送 SOS'),
                ),
              ],
            ),
          );
        },
        child: Tooltip(
          message: '长按发送 SOS',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
