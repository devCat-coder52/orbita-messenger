import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/message_status_icon.dart';

//import '../photo_viewer_screen.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String timeString;
  final String status;
  final int? editingMessageId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(String imageUrl)? onImageTap;

  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.timeString,
    required this.status,
    this.editingMessageId,
    this.onTap,
    this.onLongPress,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget messageContent;

    if (message['image_url'] != null &&
        message['image_url'].toString().isNotEmpty) {
      final isLocal = message['is_temp'] != null && message['is_temp'];
      final displayUrl = isLocal
          ? message['image_url'].toString().replaceFirst('temp:', '')
          : '${dotenv.env['BASE_URL']}${message['image_url']}';

      Widget imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isLocal
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(
                    File(displayUrl),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ],
              )
            : CachedNetworkImage(
                imageUrl: displayUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                placeholder: (_, __) =>
                    Container(width: 200, height: 200, color: Colors.grey[300]),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 50),
              ),
      );

      imageWidget = GestureDetector(
        onTap: () {
          if (!isLocal && onImageTap != null) {
            onImageTap!(displayUrl);
          }
        },
        child: imageWidget,
      );
      messageContent = imageWidget;
    } else {
      messageContent = Text(message['content'] ?? '');
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: isMe ? onLongPress : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? (message['id'] != null && editingMessageId == message['id']
                      ? const Color(0xFFB3E5FC)
                      : const Color(0xFFE3F2FD))
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              messageContent,
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeString,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  if (message['is_edited'] == true)
                    Text(
                      'ред.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(width: 4),
                  MessageStatusIcon(status: status, size: 14, isMe: isMe),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
