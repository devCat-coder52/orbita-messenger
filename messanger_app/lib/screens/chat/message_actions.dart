import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';

class ChatMessageActions {
  const ChatMessageActions();

  void onMessageTap({
    required BuildContext context,
    required Message message,
    required int? myId,
    required List<Message> messages,
    required bool isEditingThis,
    required VoidCallback onReply,
    required VoidCallback onEdit,
    required ValueChanged<Message> onDelete,
    required VoidCallback onToggleSelection,
  }) {
    final hasForwarding = messages.any((m) => m.isForwarding);
    final hasSelected = messages.any((m) => m.isSelected);

    if (hasForwarding) return;

    if (hasSelected) {
      onToggleSelection();
      return;
    }

    final t = context.app;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.reply, color: t.secondary),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply();
              },
            ),
            if (myId != null &&
                message.sender.id == myId &&
                message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(
                  isEditingThis ? 'Отменить редактирование' : 'Редактировать',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onEdit();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: t.error),
              title: Text('Удалить', style: TextStyle(color: t.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void toggleSelection(Message message, VoidCallback onChanged) {
    message.isSelected = !message.isSelected;
    onChanged();
  }

  void clearSelection(List<Message> messages, VoidCallback onChanged) {
    for (final message in messages) {
      message.isSelected = false;
    }
    onChanged();
  }

  Message? startReply(Message message) {
    if (message.id == null || message.isForwarding || message.isSystem) {
      return null;
    }
    return message.copyWith(reply: null, forward: null);
  }

  Future<void> showDeleteConfirmation({
    required BuildContext context,
    required Message message,
    required int chatId,
    required int? myId,
    required ValueChanged<bool> onDelete,
  }) async {
    final t = context.app;
    final isMine = myId != null && message.sender.id == myId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удаление сообщения'),
        content: Text(
          isMine
              ? 'Вы хотите удалить это сообщение?'
              : 'Это сообщение другого человека. Удалить его можно только у себя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onDelete(true);
            },
            child: Text('Удалить для меня', style: TextStyle(color: t.error)),
          ),
          if (isMine)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDelete(false);
              },
              child: Text('Удалить для всех', style: TextStyle(color: t.error)),
            ),
        ],
      ),
    );
  }

  Future<({bool confirmed, String? error})> deleteSelected({
    required BuildContext context,
    required List<Message> selectedMessages,
    required int chatId,
    required int? myId,
    VoidCallback? onConfirmed,
  }) async {
    if (selectedMessages.isEmpty) return (confirmed: false, error: null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удаление сообщений'),
        content: Text(
          'Вы уверены, что хотите удалить выбранные сообщения: '
          '${selectedMessages.length}? Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.app.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return (confirmed: false, error: null);

    // Сначала убираем сообщения из списка, затем сообщаем серверу.
    onConfirmed?.call();

    try {
      for (final message in selectedMessages.where((m) => m.id != null)) {
        // Чужое сообщение удаляем только у себя.
        final isLocal = myId != null && message.sender.id != myId;
        final result = await SocketService.deleteMessage(
          message.id!,
          chatId,
          isLocal,
        );
        if (!result.ok) {
          return (
            confirmed: true,
            error: 'Ошибка при удалении: ${result.error}',
          );
        }
      }
      return (confirmed: true, error: null);
    } catch (e) {
      return (confirmed: true, error: 'Ошибка при удалении: $e');
    }
  }

  List<Message> buildForwardCopies({
    required List<Message> selectedMessages,
    required dynamic sender,
  }) {
    final timeCreate = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final (i, message) in selectedMessages.indexed)
        Message(
          sender: sender,
          content: message.content,
          timeCreate: timeCreate + i,
          status: MessageStatus.forwarding,
          imageUrl: message.imageUrl,
          fileUrl: message.fileUrl,
          fileName: message.fileName,
          fileSize: message.fileSize,
          voiceUrl: message.voiceUrl,
          voiceDurationSeconds: message.voiceDurationSeconds,
          forward: message.sender.toMap(),
        ),
    ];
  }
}
