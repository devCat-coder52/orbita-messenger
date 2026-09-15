import 'package:flutter/material.dart';
//import 'dart:io';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import './chat_message_bubble.dart';
import './chat_date_header.dart';
import '../photo_viewer_screen.dart';

class ChatMessageListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final int? myId;
  final int? editingMessageId;
  final bool hasMoreMessages;
  final bool isLoadingHistory;
  final ScrollController scrollController;
  final Function(Map<String, dynamic> msg) onMessageLongPress;
  final Function(String imageUrl) onImageTap;

  const ChatMessageListWidget({
    super.key,
    required this.messages,
    this.myId,
    this.editingMessageId,
    this.hasMoreMessages = false,
    this.isLoadingHistory = false,
    required this.scrollController,
    required this.onMessageLongPress,
    required this.onImageTap,
  });

  String _getDateHeader(String isoDate) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(int.parse(isoDate));
    final now = DateTime.now();

    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDay == today) {
      return 'Сегодня';
    } else if (messageDay == yesterday) {
      return 'Вчера';
    } else {
      const months = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ];
      return '${messageDate.day} ${months[messageDate.month - 1]} ${messageDate.year}';
    }
  }

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
          var msg = messages[safeIndex];
          bool isMe = msg['sender_id'] == myId;
          int? time = msg['time_create'] != null
              ? int.parse(msg['time_create'])
              : null;
          DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time!);
          String timeString =
              '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
          String status = msg['status'] ?? 'sent';

          Widget? dateHeader;
          bool isLastMessage = index == messages.length - 1;
          bool isNewDay = false;

          if (!isLastMessage) {
            var prevMsg = messages[messages.length - 1 - (index + 1)];
            String currentDate = _getDateHeader(msg['time_create']);
            String prevDate = _getDateHeader(prevMsg['time_create']);
            if (currentDate != prevDate) {
              isNewDay = true;
            }
          } else {
            isNewDay = true;
          }

          if (isNewDay) {
            dateHeader = ChatDateHeaderWidget(
              dateText: _getDateHeader(msg['time_create']),
            );
          }

          Widget messageWidget = ChatMessageBubbleWidget(
            message: msg,
            isMe: isMe,
            timeString: timeString,
            status: status,
            editingMessageId: editingMessageId,
            onTap: () => onMessageLongPress(msg),
            onLongPress: () => (),
            onImageTap: (imageUrl) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      PhotoViewerScreen(imageUrl: imageUrl),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          );

          return isNewDay && dateHeader != null
              ? Column(children: [dateHeader, messageWidget])
              : messageWidget;
        },
      ),
    );
  }
}
