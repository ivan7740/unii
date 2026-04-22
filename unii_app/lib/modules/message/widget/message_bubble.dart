import 'package:flutter/material.dart';
import '../../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String currentNickname;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.currentNickname = '',
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSos) {
      return _buildSosBubble(context);
    }
    return _buildNormalBubble(context);
  }

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
            backgroundColor: Colors.yellow.withValues(alpha: 0.35),
          ),
        ));
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildNormalBubble(BuildContext context) {
    final theme = Theme.of(context);
    final isQuick = message.msgType == 'quick';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                message.senderNickname.isNotEmpty
                    ? message.senderNickname[0]
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderNickname,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary
                        : isQuick
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
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
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSosBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sos, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'SOS 紧急求助',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${message.senderNickname}：${message.content}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
