import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../profile_screen.dart';
import '../../utils/app_colors.dart';
import '../../widgets/message_status_icon.dart';
import '../../widgets/voice_message_player.dart';

import '../../models/message.dart';
import '../../models/member.dart';
import '../../theme/app_theme.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  final Message message;
  final int? myId;
  final String timeString;
  final String status;
  final int? editingMessageId;
  final int selectedCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTemp;
  final void Function(Message replyTo)? onQuoteTap;
  final void Function(String imageUrl)? onImageTap;
  final void Function(String fileUrl, String fileName)? onFileTap;

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

  bool get _isMe => message.sender.id == myId;
  bool get _isForwarding => message.isForwarding;
  bool get _hasImage => message.hasImage;
  bool get _hasFile => message.hasFile;
  bool get _hasVoice => message.hasVoice;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Widget _buildReplyHeader(BuildContext context, Message replied) {
    final t = context.app;
    final authorName = replied.sender.id == myId ? 'Вы' : replied.sender.name;

    final text = replied.content.replaceAll('\n', ' ');
    final previewText = text.isNotEmpty
        ? text
        : replied.hasVoice
        ? 'Голосовое сообщение'
        : replied.hasImage
        ? 'Фотография'
        : replied.hasFile
        ? 'Файл: ${replied.fileName}'
        : 'Пустое сообщение';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onQuoteTap?.call(replied),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.textPrimary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: Theme.of(context).primaryColor, width: 2.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 13, color: t.textSecondary),
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
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
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

  Widget _buildForwardHeader(BuildContext context, Member originalSender) {
    final t = context.app;
    final avatarUrl = originalSender.avatarUrl;
    final forwardId = originalSender.id;
    final canOpenProfile = !_isForwarding;

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
              color: t.textSecondary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 10,
              backgroundColor: t.divider,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(
                      '${dotenv.env['BASE_URL']}/$avatarUrl',
                    )
                  : null,
              child: avatarUrl != null
                  ? null
                  : Icon(Icons.person, size: 12, color: t.hint),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                originalSender.name,
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

  Widget _buildImageContent(BuildContext context) {
    final t = context.app;
    final isLocal = message.isTemp;
    final rawUrl = message.imageUrl!;
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
                  color: t.overlayDark,
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
              placeholder: (_, _) => Container(
                width: _maxImageSize,
                height: _maxImageSize,
                color: t.divider,
              ),
              errorWidget: (_, _, _) => Container(
                width: _maxImageSize,
                height: _maxImageSize,
                color: t.surfaceVariant,
                child: Center(
                  child: Text(
                    'Изображение недоступно',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: t.hint,
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
    final t = context.app;
    final isLocal = message.isTemp;
    final rawUrl = message.fileUrl!;
    final fileName = message.fileName ?? 'Файл';
    final sizeBytes = message.fileSize;
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
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
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 14,
        height: 1.3,
        color: context.app.textPrimary,
      ),
    );
  }

  Widget _buildVoiceContent() {
    final isLocal = message.isTemp;
    final duration = message.voiceDurationSeconds ?? 0;

    return VoiceMessagePlayer(
      voiceUrl: message.voiceUrl!,
      durationSeconds: duration,
      isMe: _isMe,
      isLocal: isLocal,
    );
  }

  Widget _buildMetaInfo(BuildContext context) {
    final t = context.app;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited) ...[
          Text(
            'ред.',
            style: TextStyle(
              fontSize: 10,
              color: t.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          timeString,
          style: TextStyle(fontSize: 10, color: t.textSecondary),
        ),
        const SizedBox(width: 4),
        MessageStatusIcon(status: status, size: 14, isMe: _isMe),
      ],
    );
  }

  Widget _buildSelectionCheckbox(BuildContext context) {
    final isSelected = message.isSelected;
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
    final forwardFrom = message.forward;
    final hasForwardHeader = forwardFrom != null;
    final replyPayload = message.reply;
    final hasReplyHeader = replyPayload != null && replyPayload.isNotEmpty;
    final hasImage = _hasImage;
    final hasFile = _hasFile;
    final hasVoice = _hasVoice;

    final bubbleColor =
        _isMe && message.id != null && editingMessageId == message.id
        ? AppColors.bubbleEditing
        : (_isMe ? AppColors.bubbleMine : Colors.grey[200]);

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
                _buildForwardHeader(context, Member.fromMap(forwardFrom)),
              if (hasReplyHeader)
                _buildReplyHeader(context, Message.fromJson(replyPayload)),
              if (hasImage)
                _buildImageContent(context)
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
                      Flexible(child: _buildTextContent(context)),
                      const SizedBox(width: 6),
                      _buildMetaInfo(context),
                    ],
                  ),
                ),
              if (hasImage && !_isForwarding) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildMetaInfo(context),
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
