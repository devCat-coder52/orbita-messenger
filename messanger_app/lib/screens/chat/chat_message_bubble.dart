import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/message_status_icon.dart';
import '../profile_screen.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String timeString;
  final String status;
  final int? editingMessageId;
  final int selectedCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTemp;
  final Function(String imageUrl)? onImageTap;

  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.timeString,
    required this.status,
    this.editingMessageId,
    required this.selectedCount,
    this.onTap,
    this.onLongPress,
    this.onDeleteTemp,
    this.onImageTap,
  });

  static const double _maxImageWidth = 200.0;

  Widget _buildForwardHeader(
    Map<String, dynamic> data,
    BuildContext context,
    double bubbleInnerWidth,
  ) {
    return GestureDetector(
      onTap: message['status'] != 'forwarding'
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userId: message['forward']['id']),
                ),
              );
            }
          : null,
      child: Container(
        width: bubbleInnerWidth,
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              Icons.forward,
              size: 14,
              color: Colors.grey[500]?.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Opacity(
              opacity: data['status'] == 'forwarding' ? 0.4 : 1.0,
              child: CircleAvatar(
                radius: 10,
                backgroundImage: data['avatar_url'] != null
                    ? NetworkImage(
                        '${dotenv.env['BASE_URL']}/${data['avatar_url']}',
                      )
                    : null,
                backgroundColor: Colors.grey[500],
                child: data['avatar_url'] != null
                    ? null
                    : const Icon(Icons.person, size: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor.withValues(
                    alpha: data['status'] == 'forwarding' ? 0.4 : 0.8,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget messageContent;
    double bubbleWidth = MediaQuery.of(context).size.width * 0.7 - 24;

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
                    width: _maxImageWidth,
                    height: _maxImageWidth,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: _maxImageWidth,
                    height: _maxImageWidth,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
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
            : Opacity(
                opacity: message['status'] == 'forwarding' ? 0.4 : 1.0,
                child: CachedNetworkImage(
                  imageUrl: displayUrl,
                  width: _maxImageWidth,
                  height: _maxImageWidth,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  placeholder: (_, __) => Container(
                    width: _maxImageWidth,
                    height: _maxImageWidth,
                    color: Colors.grey[300],
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 50),
                ),
              ),
      );

      imageWidget = GestureDetector(
        onTap: () {
          if (selectedCount > 0) {
            onTap!();
          } else if (!isLocal && onImageTap != null) {
            onImageTap!(displayUrl);
          }
        },
        child: imageWidget,
      );
      messageContent = imageWidget;
      bubbleWidth = _maxImageWidth;
    } else {
      final text = message['content'] ?? '';
      final painter = TextPainter(
        text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();
      bubbleWidth = painter.width.clamp(
        0.0,
        MediaQuery.of(context).size.width * 0.7 - 24,
      );
      messageContent = Text(
        text,
        style: TextStyle(
          color: Colors.black.withValues(
            alpha: message['status'] == 'forwarding' ? 0.4 : 1.0,
          ),
        ),
      );
    }

    if (message.containsKey('forward') && message['forward'] != null) {
      final namePainter = TextPainter(
        text: TextSpan(
          text: message['forward']['name'] ?? 'Unknown',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final headerNaturalWidth = namePainter.width + 14 + 4 + 20 + 6;
      final maxInnerWidth = MediaQuery.of(context).size.width * 0.7 - 24;
      if (headerNaturalWidth > bubbleWidth) {
        bubbleWidth = headerNaturalWidth.clamp(0.0, maxInnerWidth);
      }
    }

    final hasForwardHeader =
        message.containsKey('forward') && message['forward'] != null;
    final fitsInline =
        !hasForwardHeader &&
        message['status'] != 'forwarding' &&
        _textFitsInline(context, bubbleWidth);

    Widget contentRow;
    if (fitsInline) {
      contentRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: messageContent),
          const SizedBox(width: 6),
          Align(alignment: Alignment.bottomCenter, child: _buildMetaInfo()),
        ],
      );
    } else {
      contentRow = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          messageContent,
          const SizedBox(height: 4),
          if (message['status'] != 'forwarding') _buildMetaInfo(),
        ],
      );
    }

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe && selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: GestureDetector(
                  onTap: onTap,
                  child: Icon(
                    message['is_selected']
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 24,
                    color: message['is_selected']
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),

        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            margin: EdgeInsets.symmetric(
              vertical: 4,
              horizontal: selectedCount > 0 ? 4.0 : 8.0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe
                  ? (message['id'] != null && editingMessageId == message['id']
                        ? const Color(0xFFB3E5FC)
                        : message['status'] == 'forwarding'
                        ? const Color(0xFFE3F2FD).withValues(alpha: 0.4)
                        : const Color(0xFFE3F2FD))
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasForwardHeader)
                  _buildForwardHeader(message['forward'], context, bubbleWidth),
                contentRow,
              ],
            ),
          ),
        ),

        if (isMe && selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: GestureDetector(
                  onTap: onTap,
                  child: Icon(
                    message['is_selected']
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 24,
                    color: message['is_selected']
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),

        if (message['status'] == 'forwarding')
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: GestureDetector(
                  onTap: onDeleteTemp,
                  child: Icon(
                    Icons.remove_circle,
                    size: 24,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Row(
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
    );
  }

  bool _textFitsInline(BuildContext context, double availableWidth) {
    final text = message['content'] ?? '';
    if (text.isEmpty) return false;
    final metaWidth = _measureMetaWidth(context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width + metaWidth + 6 <= availableWidth;
  }

  double _measureMetaWidth(BuildContext context) {
    final timePainter = TextPainter(
      text: TextSpan(text: timeString, style: const TextStyle(fontSize: 10)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    double width = timePainter.width + 4;

    if (message['is_edited'] == true) {
      final editPainter = TextPainter(
        text: const TextSpan(text: 'ред.', style: TextStyle(fontSize: 10)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      width += editPainter.width + 4;
    }

    width += 14;

    return width;
  }
}
