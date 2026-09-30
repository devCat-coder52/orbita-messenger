import 'package:flutter/material.dart';

class ChatInputPanelWidget extends StatelessWidget {
  final TextEditingController textController;
  final Color primaryColor;
  final Color borderColor;
  final VoidCallback onSendPressed;
  final VoidCallback onAddPressed;
  final Map<String, dynamic>? replyingTo;
  final int? myId;
  final String? myName;
  final VoidCallback? onCancelReply;

  const ChatInputPanelWidget({
    super.key,
    required this.textController,
    this.primaryColor = const Color(0xFF2C3E50),
    required this.borderColor,
    required this.onSendPressed,
    required this.onAddPressed,
    this.replyingTo,
    this.myId,
    this.myName,
    this.onCancelReply,
  });

  String get _replyAuthorName {
    final sender = replyingTo?['sender'];
    if (sender != null && sender['id'] == myId) return 'Вы';
    return sender?['name'] ?? 'UNKNOWN_NAME';
  }

  String get _replyPreviewText {
    final imageUrl = (replyingTo?['image_url'] ?? '').toString();
    final text = (replyingTo?['content'] ?? '').toString();
    if (imageUrl.isNotEmpty && text.isEmpty) return 'Изображение';
    if (text.isEmpty) return 'EMPTY_MESSAGE';
    return text.replaceAll('\n', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyingTo != null) _buildReplyPreview(context),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF2C3E50)),
                  onPressed: onAddPressed,
                  padding: const EdgeInsets.all(2.0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: textController,
                    maxLength: 230,
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: replyingTo != null
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
                          backgroundColor: primaryColor,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: onSendPressed,
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
          border: Border(left: BorderSide(color: primaryColor, width: 3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 18, color: Color(0xFF2C3E50)),
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
              onPressed: onCancelReply,
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
