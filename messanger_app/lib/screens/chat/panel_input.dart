import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../models/message.dart';

class ChatInputPanelWidget extends StatefulWidget {
  final TextEditingController textController;
  final Color borderColor;
  final VoidCallback onSendPressed;
  final VoidCallback onPickImagePressed;
  final VoidCallback onPickFilePressed;
  final VoidCallback? onPickRecordPressed;
  final Message? replyingTo;
  final int? myId;
  final String? myName;
  final VoidCallback? onCancelReply;

  const ChatInputPanelWidget({
    super.key,
    required this.textController,
    required this.borderColor,
    required this.onSendPressed,
    required this.onPickImagePressed,
    required this.onPickFilePressed,
    this.onPickRecordPressed,
    this.replyingTo,
    this.myId,
    this.myName,
    this.onCancelReply,
  });

  @override
  State<ChatInputPanelWidget> createState() => _ChatInputPanelWidgetState();
}

class _ChatInputPanelWidgetState extends State<ChatInputPanelWidget> {
  bool get _showMicButton =>
      widget.textController.text.trim().isEmpty &&
      widget.onPickRecordPressed != null;

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
    if (reply.sender.id == widget.myId) return 'Вы';
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
                subtitle: const Text(
                  'Зажмите кнопку микрофона в панели ввода',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyingTo != null) _buildReplyPreview(context),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: widget.borderColor),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF2C3E50)),
                  onPressed: () => _showAttachmentSheet(context),
                  padding: const EdgeInsets.all(2.0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: widget.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.textController,
                    maxLength: 230,
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: widget.replyingTo != null
                          ? 'Введите ответ...'
                          : 'Введите сообщение...',
                      counterText: '',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
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
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            icon: Icon(
                              _showMicButton ? Icons.mic : Icons.send,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _showMicButton
                                ? widget.onPickRecordPressed
                                : widget.onSendPressed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ответ: $_replyAuthorName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _replyPreviewText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
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
