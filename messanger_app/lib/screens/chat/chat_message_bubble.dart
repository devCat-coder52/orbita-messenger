import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../widgets/message_status_icon.dart';
import '../../widgets/voice_message_player.dart';
import '../profile_screen.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final int? myId;
  final String timeString;
  final String status;
  final int? editingMessageId;
  final int selectedCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTemp;
  final Function(Map<String, dynamic> replyTo)? onQuoteTap;
  final Function(String imageUrl)? onImageTap;
  final Function(String fileUrl, String fileName)? onFileTap;

  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    this.myId,
    required this.timeString,
    required this.status,
    this.editingMessageId,
    required this.selectedCount,
    this.onTap,
    this.onLongPress,
    this.onDeleteTemp,
    this.onQuoteTap,
    this.onImageTap,
    this.onFileTap,
  });

  static const double _maxImageSize = 200.0;

  bool get _isMe => message['sender']?['id'] == myId;
  bool get _isForwarding => message['status'] == 'forwarding';
  bool get _hasImage =>
      message['image_url'] != null &&
      message['image_url'].toString().isNotEmpty;
  bool get _hasFile =>
      message['file_url'] != null && message['file_url'].toString().isNotEmpty;
  bool get _hasVoice =>
      message['voice_url'] != null &&
      message['voice_url'].toString().isNotEmpty;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Widget _buildReplyHeader(BuildContext context, Map<String, dynamic> data) {
    final sender = message['sender'];
    final isMyReply = sender is Map && myId != null && myId == sender['id'];
    final authorName = isMyReply ? 'Вы' : (sender?['name'] ?? 'Unknown');

    final imageUrl = (data['image_url'] ?? '').toString();
    final fileName = (data['file_name'] ?? '').toString();
    final text = (data['content'] ?? '').toString().replaceAll('\n', ' ');
    final previewText = text.isNotEmpty
        ? text
        : _hasVoice
        ? 'Голосовое сообщение'
        : (imageUrl.isNotEmpty
              ? 'Фотография'
              : (fileName.isNotEmpty ? 'Файл: $fileName' : 'Пустое сообщение'));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onQuoteTap?.call(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: Theme.of(context).primaryColor, width: 2.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 13, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ответ: $authorName',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    previewText,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForwardHeader(BuildContext context, Map<String, dynamic> data) {
    final avatarUrl = data['avatar_url'];
    final forwardId = data['id'];
    final canOpenProfile = !_isForwarding && forwardId != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canOpenProfile
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: forwardId),
                ),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forward,
              size: 14,
              color: Colors.grey[600]?.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.grey[400],
              backgroundImage: avatarUrl != null
                  ? NetworkImage('${dotenv.env['BASE_URL']}/$avatarUrl')
                  : null,
              child: avatarUrl != null
                  ? null
                  : const Icon(Icons.person, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
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

  Widget _buildImageContent() {
    final isLocal = message['is_temp'] == true;
    final rawUrl = message['image_url'].toString();
    final displayUrl = isLocal
        ? rawUrl.replaceFirst('temp:', '')
        : '${dotenv.env['BASE_URL']}$rawUrl';

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isLocal
          ? Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  File(displayUrl),
                  width: _maxImageSize,
                  height: _maxImageSize,
                  fit: BoxFit.cover,
                ),
                Container(
                  width: _maxImageSize,
                  height: _maxImageSize,
                  color: Colors.black.withValues(alpha: 0.3),
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
              width: _maxImageSize,
              height: _maxImageSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: _maxImageSize,
                height: _maxImageSize,
                color: Colors.grey[300],
              ),
              errorWidget: (_, __, ___) => Container(
                width: _maxImageSize,
                height: _maxImageSize,
                color: Colors.grey[200],
                child: const Center(
                  child: Text(
                    'Изображение недоступно',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
    );

    return GestureDetector(
      onTap: () {
        if (selectedCount > 0) {
          onTap?.call();
        } else if (!isLocal) {
          onImageTap?.call(displayUrl);
        }
      },
      child: image,
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final isLocal = message['is_temp'] == true;
    final rawUrl = message['file_url'].toString();
    final fileName = (message['file_name'] ?? 'Файл').toString();
    final sizeBytes = int.tryParse(message['file_size']?.toString() ?? '');
    final displayUrl = isLocal
        ? rawUrl.replaceFirst('temp:', '')
        : '${dotenv.env['BASE_URL']}$rawUrl';

    return GestureDetector(
      onTap: () {
        if (selectedCount > 0) {
          onTap?.call();
        } else if (!isLocal) {
          onFileTap?.call(displayUrl, fileName);
        }
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        /*decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),*/
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocal ? Icons.hourglass_empty : Icons.description_outlined,
              size: 30,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isLocal
                        ? 'Загрузка…'
                        : (sizeBytes != null
                              ? _formatFileSize(sizeBytes)
                              : 'Нажмите, чтобы скачать'),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Text(
      (message['content'] ?? '').toString(),
      style: const TextStyle(fontSize: 14, height: 1.3, color: Colors.black),
    );
  }

  Widget _buildVoiceContent() {
    final isLocal = message['is_temp'] == true;
    final duration =
        int.tryParse(message['voice_duration']?.toString() ?? '') ?? 0;

    return VoiceMessagePlayer(
      voiceUrl: message['voice_url'].toString(),
      durationSeconds: duration,
      isMe: _isMe,
      isLocal: isLocal,
    );
  }

  Widget _buildMetaInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message['is_edited'] == true) ...[
          Text(
            'ред.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          timeString,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(width: 4),
        MessageStatusIcon(status: status, size: 14, isMe: _isMe),
      ],
    );
  }

  Widget _buildSelectionCheckbox(BuildContext context) {
    final isSelected = message['is_selected'] == true;
    return SizedBox(
      width: 30,
      height: 30,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            size: 24,
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteForwarding(BuildContext context) {
    return SizedBox(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasForwardHeader = message['forward'] is Map;
    final replyTo = message['reply'];
    final hasReplyHeader = replyTo is Map && replyTo.isNotEmpty;
    final hasImage = _hasImage;
    final hasFile = _hasFile;
    final hasVoice = _hasVoice;
    final hasMedia = hasImage || hasFile || hasVoice;

    final bubbleColor =
        _isMe && message['id'] != null && editingMessageId == message['id']
        ? const Color(0xFFB3E5FC)
        : (_isMe ? const Color(0xFFE3F2FD) : Colors.grey[200]);

    final bubble = Opacity(
      opacity: _isForwarding ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          margin: EdgeInsets.symmetric(
            vertical: 4,
            horizontal: selectedCount > 0 ? 4.0 : 8.0,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasForwardHeader)
                _buildForwardHeader(context, message['forward']),
              if (hasReplyHeader)
                _buildReplyHeader(context, Map<String, dynamic>.from(replyTo)),
              if (hasImage)
                _buildImageContent()
              else if (hasFile)
                _buildFileContent(context)
              else if (hasVoice) ...[
                _buildVoiceContent(),
                /*if (!_isForwarding) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildMetaInfo(),
                  ),
                ],*/
              ] else
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: _buildTextContent()),
                      const SizedBox(width: 6),
                      _buildMetaInfo(),
                    ],
                  ),
                ),
              if (hasImage && !_isForwarding) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildMetaInfo(),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: _isMe
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (selectedCount > 0 && !_isMe)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildSelectionCheckbox(context),
          ),
        Flexible(child: bubble),
        if (selectedCount > 0 && _isMe)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: _buildSelectionCheckbox(context),
          ),
        if (_isForwarding)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: _buildDeleteForwarding(context),
          ),
      ],
    );
  }
}
