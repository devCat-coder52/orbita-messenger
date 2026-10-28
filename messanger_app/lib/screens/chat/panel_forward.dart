import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatForwardPanelWidget extends StatelessWidget {
  final int messageCount;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const ChatForwardPanelWidget({
    super.key,
    required this.messageCount,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: t.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: t.hint),
            onPressed: onCancel,
            tooltip: 'Отменить пересылку',
          ),
          Expanded(
            child: Text(
              'Пересылаемых сообщений: $messageCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: t.secondary,
            child: IconButton(
              icon: Icon(Icons.reply, size: 22, color: t.textOnAccent),
              onPressed: onSend,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}
