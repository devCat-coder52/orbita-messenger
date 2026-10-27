import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import './message_bubble.dart';
import '../../utils/time_formatter.dart';
import '../../models/message.dart';
import '../../widgets/fade_slide.dart';

class ChatMessageListWidget extends StatelessWidget {
  final List<Message> messages;
  final int? myId;
  final int? editingMessageId;
  final int selectedCount;
  final bool hasMoreMessages;
  final bool isLoadingHistory;
  final ScrollController scrollController;
  final void Function(Message msg) onMessageTap;
  final void Function(Message msg) onMessageLongPress;
  final void Function(Message msg) onDeleteForwardedMessage;
  final void Function(Message replyTo) onReplyTap;
  final Function(int messageId) onScrollToMessage;
  final Function(String imageUrl) onImageTap;
  final void Function(String fileUrl, String fileName)? onFileTap;

  static const Duration _freshWindow = Duration(seconds: 3);

  const ChatMessageListWidget({
    super.key,
    required this.messages,
    this.myId,
    required this.selectedCount,
    this.editingMessageId,
    this.hasMoreMessages = false,
    this.isLoadingHistory = false,
    required this.scrollController,
    required this.onMessageTap,
    required this.onMessageLongPress,
    required this.onDeleteForwardedMessage,
    required this.onReplyTap,
    required this.onScrollToMessage,
    required this.onImageTap,
    required this.onFileTap,
  });

  String _getDateHeader(DateTime messageDate) =>
      TimeFormatter.dateHeader(messageDate);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: messages.length + (hasMoreMessages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length && hasMoreMessages) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final safeIndex = messages.length - 1 - index;
          if (safeIndex < 0 || safeIndex >= messages.length) {
            return const SizedBox.shrink();
          }
          final msg = messages[safeIndex];
          final timeString = TimeFormatter.time(msg.createdAt);
          final status = msg.status.wire;

          Widget? dateHeader;
          bool isLastMessage = index == messages.length - 1;
          bool isNewDay = false;

          if (!isLastMessage) {
            final prevMsg = messages[messages.length - 1 - (index + 1)];
            String msgDate = DateFormat(
              'yyyy-MM-dd',
              'ru_RU',
            ).format(msg.createdAt);
            String prevMsgDate = DateFormat(
              'yyyy-MM-dd',
              'ru_RU',
            ).format(prevMsg.createdAt);
            if (msgDate != prevMsgDate) {
              isNewDay = true;
            }
          } else {
            isNewDay = true;
          }

          if (isNewDay) {
            dateHeader = Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDateHeader(msg.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
            );
          }

          Widget messageWidget = ChatMessageBubbleWidget(
            message: msg,
            myId: myId,
            timeString: timeString,
            status: status,
            selectedCount: selectedCount,
            editingMessageId: editingMessageId,
            onTap: () => onMessageTap(msg),
            onLongPress: () => onMessageLongPress(msg),
            onDeleteTemp: () => onDeleteForwardedMessage(msg),
            onQuoteTap: (replyTo) {
              if (replyTo.id != null) onScrollToMessage(replyTo.id!);
            },
            onImageTap: onImageTap,
            onFileTap: onFileTap,
          );

          final isFresh =
              DateTime.now().difference(msg.createdAt) < _freshWindow;
          if (isFresh) {
            messageWidget = FadeSlideIn(
              animationKey: '${msg.id ?? msg.timeCreate}',
              beginOffset: const Offset(0, 14),
              child: messageWidget,
            );
          }

          return isNewDay && dateHeader != null
              ? Column(children: [dateHeader, messageWidget])
              : messageWidget;
        },
      ),
    );
  }
}
