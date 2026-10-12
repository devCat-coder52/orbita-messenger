import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';

class ChatMessageActions {
  const ChatMessageActions();

  void onMessageTap({
    required BuildContext context,
    required Message message,
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

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.secondary),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply();
              },
            ),
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
    if (message.id == null || message.isForwarding) return null;
    return message.copyWith(reply: null, forward: null);
  }

  bool? prepareEditing({
    required Message message,
    required int? currentEditingId,
    required TextEditingController textController,
  }) {
    if (message.id == null) return null;
    if (currentEditingId == message.id) {
      textController.clear();
      return true;
    }
    textController.text = message.content;
    return false;
  }

  Future<void> showDeleteConfirmation({
    required BuildContext context,
    required Message message,
    required int chatId,
    required int? myId,
    required VoidCallback onBeforeDelete,
    required VoidCallback onLocalDeleted,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удаление сообщения'),
        content: const Text('Вы хотите удалить это сообщение?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              SocketService.deleteMessage(message.id!, chatId);
              onLocalDeleted();
            },
            child: const Text(
              'Удалить для меня',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onBeforeDelete();
            },
            child: Text(
              'Удалить для всех',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> deleteSelected({
    required BuildContext context,
    required List<Message> selectedMessages,
    required int chatId,
  }) async {
    if (selectedMessages.isEmpty) return null;

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;

    try {
      for (final message in selectedMessages.where((m) => m.id != null)) {
        final result = await SocketService.deleteMessage(
          message.id!,
          chatId,
          isLocal: false,
        );
        if (!result.ok) {
          return 'Ошибка при удалении: ${result.error}';
        }
      }
      return null;
    } catch (e) {
      return 'Ошибка при удалении: $e';
    }
  }

  List<Message> buildForwardCopies({
    required List<Message> selectedMessages,
    required dynamic sender,
  }) {
    final timeCreate = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final message in selectedMessages)
        Message(
          sender: sender,
          content: message.content,
          timeCreate: timeCreate,
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
