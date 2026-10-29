import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/message.dart';
import 'panel_forward.dart';

class ChatInputPanelWidget extends StatefulWidget {
  final TextEditingController textController;
  final VoidCallback onSendPressed;
  final VoidCallback onPickImagePressed;
  final VoidCallback onPickFilePressed;
  final VoidCallback? onPickRecordPressed;
  final Message? replyingTo;
  final int? myId;
  final String? myName;
  final VoidCallback? onCancelReply;
  final int? forwardCount;
  final VoidCallback? onCancelForward;

  const ChatInputPanelWidget({
    super.key,
    required this.textController,
    required this.onSendPressed,
    required this.onPickImagePressed,
    required this.onPickFilePressed,
    this.onPickRecordPressed,
    this.replyingTo,
    this.myId,
    this.myName,
    this.onCancelReply,
    this.forwardCount,
    this.onCancelForward,
  });

  @override
  State<ChatInputPanelWidget> createState() => _ChatInputPanelWidgetState();
}

class _ChatInputPanelWidgetState extends State<ChatInputPanelWidget> {
  bool get _showMicButton =>
      widget.textController.text.trim().isEmpty &&
      widget.onPickRecordPressed != null;

  bool sendPressed = false;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  String get _replyAuthorName {
    final reply = widget.replyingTo;
    if (reply == null) return 'UNKNOWN_NAME';
    if (reply.id == null || reply.sender.id == widget.myId) return 'Вы';
    return reply.sender.name;
  }

  String get _replyPreviewText {
    final reply = widget.replyingTo;
    if (reply == null) return 'EMPTY_MESSAGE';
    final text = reply.content;
    if (text.isEmpty && reply.hasImage) return 'Изображение';
    if (text.isEmpty && reply.hasFile) return 'Файл: ${reply.fileName}';
    if (text.isEmpty && reply.hasVoice) return 'Голосовое сообщение';
    if (text.isEmpty) return 'EMPTY_MESSAGE';
    return text.replaceAll('\n', ' ');
  }

  void _showAttachmentSheet(BuildContext context) {
    final t = context.app;
    final isForwardMode = widget.forwardCount != null;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Фотография'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onPickImagePressed();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Файл'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onPickFilePressed();
              },
            ),
            if (widget.onPickRecordPressed != null)
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Голосовое сообщение'),
                subtitle: Text(
                  'Зажмите кнопку микрофона в панели ввода',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onPickRecordPressed?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    final isForwardMode = widget.forwardCount != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.replyingTo != null
              ? _buildReplyPreview(context)
              : const SizedBox(width: double.infinity),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isForwardMode ? 8.0 : 16.0,
            vertical: isForwardMode ? 4.0 : 12.0,
          ),
          color: isForwardMode ? t.surface.withValues(alpha: 0.55) : t.surface,
          child: isForwardMode
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ChatForwardPanelWidget(
                    messageCount: widget.forwardCount!,
                    onCancel: widget.onCancelForward ?? () {},
                    onSend: widget.onSendPressed,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.divider),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: t.cardShadow,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: t.textPrimary),
                        onPressed: () => _showAttachmentSheet(context),
                        padding: const EdgeInsets.all(2.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surfaceVariant,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: t.divider),
                        ),
                        child: TextField(
                          controller: widget.textController,
                          maxLength: 230,
                          textInputAction: TextInputAction.send,
                          maxLines: null,
                          style: TextStyle(fontSize: 14, color: t.textPrimary),
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: widget.replyingTo != null
                                ? 'Введите ответ...'
                                : 'Введите сообщение...',
                            counterText: '',
                            hintStyle: TextStyle(color: t.hint),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => sendPressed = true),
                                onTapUp: (_) =>
                                    setState(() => sendPressed = false),
                                onTapCancel: () =>
                                    setState(() => sendPressed = false),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_showMicButton) {
                                    widget.onPickRecordPressed?.call();
                                  } else {
                                    widget.onSendPressed();
                                  }
                                },
                                child: AnimatedScale(
                                  scale: sendPressed ? 0.85 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: t.secondary,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        _showMicButton ? Icons.mic : Icons.send,
                                        key: ValueKey(
                                          _showMicButton ? 'mic' : 'send',
                                        ),
                                        size: 18,
                                        color: t.textOnAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final t = context.app;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      color: t.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: t.bubbleMine,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: t.secondary, width: 3)),
        ),
        child: Row(
          children: [
            Icon(Icons.reply, size: 18, color: t.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ответ: $_replyAuthorName',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _replyPreviewText,
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: t.hint),
              onPressed: widget.onCancelReply,
              tooltip: 'Отменить ответ',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
