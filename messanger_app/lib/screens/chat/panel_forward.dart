import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
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
            backgroundColor: const Color(0xFF2C3E50),
            child: IconButton(
              icon: const Icon(Icons.reply, size: 22, color: Colors.white),
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
