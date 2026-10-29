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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, size: 18, color: t.hint),
            onPressed: onCancel,
            tooltip: 'Отменить пересылку',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          Expanded(
            child: Text(
              'Пересылаемых сообщений: $messageCount',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: t.secondary,
            child: IconButton(
              icon: Icon(Icons.reply, size: 16, color: t.textOnAccent),
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
