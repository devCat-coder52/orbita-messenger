import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../profile_screen.dart';
import '../../services/link_launcher.dart';
import '../../widgets/linkified_text.dart';
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
          border: Border(left: BorderSide(color: t.secondary, width: 2.5)),
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
                      color: t.secondary.withValues(alpha: 0.9),
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
                  color: t.secondary,
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
                  child: Center(
                    child: CircularProgressIndicator(
                      color: t.textOnAccent,
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
      child: SizedBox(
        width: _maxImageSize,
        height: _maxImageSize,
        child: image,
      ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocal ? Icons.hourglass_empty : Icons.description_outlined,
              size: 30,
              color: t.secondary,
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

  static const double _metaHeight = 13;
  static const double _metaGap = 6;

  bool _isShortMessage(BuildContext context, double metaWidth) {
    final contentWidth = _measureTextWidth(
      context,
      message.content,
      _textStyle(context),
    );
    final maxContentWidth = MediaQuery.sizeOf(context).width * 0.7 - 20;
    return contentWidth + metaWidth + _metaGap <= maxContentWidth;
  }

  TextStyle _textStyle(BuildContext context) =>
      TextStyle(fontSize: 14, height: 1.3, color: context.app.textPrimary);

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: null,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _metaWidth(BuildContext context) {
    final style = _metaStyle(context);
    var width = _measureTextWidth(context, timeString, style);
    if (message.isEdited) {
      width += 3 + _measureTextWidth(context, 'изм.', style);
    }
    if (_isMe && status.isNotEmpty && status != 'forwarding') {
      width += 3 + 13; // отступ + иконка статуса
    }
    return width + 2; // запас, чтобы плашка не обрезалась
  }

  Widget _buildTextWithMeta(BuildContext context) {
    final metaWidth = _metaWidth(context);
    final reserve =
        metaWidth + (_isShortMessage(context, metaWidth) ? _metaGap : 0);

    return Stack(
      children: [
        LinkifiedText(
          text: message.content,
          style: _textStyle(context),
          linkColor: context.app.secondary,
          reserve: reserve,
          reserveHeight: _metaHeight,
          onLinkTap: (uri) => _openLink(context, uri),
        ),
        PositionedDirectional(
          end: 0,
          bottom: 1,
          child: _buildMetaInfo(context),
        ),
      ],
    );
  }

  Future<void> _openLink(BuildContext context, String uri) async {
    final opened = await LinkLauncher.open(uri);
    if (opened || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: uri));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ссылка скопирована: $uri')));
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

  TextStyle _metaStyle(BuildContext context) =>
      TextStyle(fontSize: 10.5, height: 1.0, color: context.app.textSecondary);

  Widget _buildMetaInfo(BuildContext context) {
    final showStatus = _isMe && status.isNotEmpty && status != 'forwarding';
    final style = _metaStyle(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.isEdited) ...[
          Text('изм.', style: style),
          const SizedBox(width: 3),
        ],
        Text(timeString, style: style),
        if (showStatus) ...[
          const SizedBox(width: 3),
          MessageStatusIcon(status: status, size: 13, isMe: _isMe),
        ],
      ],
    );
  }

  Widget _buildSelectionCheckbox(BuildContext context) {
    final t = context.app;
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
            color: isSelected ? t.secondary : t.hint,
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
          child: Icon(Icons.remove_circle, size: 24, color: context.app.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    final forwardFrom = message.forward;
    final hasForwardHeader = forwardFrom != null;
    final replyPayload = message.reply;
    final hasReplyHeader = replyPayload != null && replyPayload.isNotEmpty;
    final hasImage = _hasImage;
    final hasFile = _hasFile;
    final hasVoice = _hasVoice;

    final bubbleColor =
        _isMe && message.id != null && editingMessageId == message.id
        ? t.bubbleEditing
        : (_isMe ? t.bubbleMine : t.bubbleTheirs);

    final String contentDescription;
    if (hasVoice) {
      contentDescription = 'Голосовое сообщение, $timeString';
    } else if (hasImage) {
      contentDescription = 'Фотография, $timeString';
    } else if (hasFile) {
      contentDescription = 'Файл ${message.fileName ?? ''}, $timeString';
    } else {
      contentDescription =
          '${message.content}. $timeString. ${_isMe ? "Отправлено вами" : ""}';
    }

    final bubble = Opacity(
      opacity: _isForwarding ? 0.4 : 1.0,
      child: Semantics(
        label: contentDescription,
        button: true,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          excludeFromSemantics: true,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            margin: EdgeInsets.symmetric(
              vertical: 4,
              horizontal: selectedCount > 0 ? 4.0 : 8.0,
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasForwardHeader)
                    _buildForwardHeader(context, Member.fromMap(forwardFrom)),
                  if (hasReplyHeader)
                    _buildReplyHeader(context, Message.fromJson(replyPayload)),
                  if (!hasImage && !hasFile && !hasVoice)
                    _buildTextWithMeta(context)
                  else ...[
                    if (hasImage)
                      _buildImageContent(context)
                    else if (hasFile)
                      _buildFileContent(context)
                    else
                      _buildVoiceContent(),
                    const SizedBox(height: 2),
                    _buildMetaInfo(context),
                  ],
                ],
              ),
            ),
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
