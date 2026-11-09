import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/message.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_formatter.dart';
import '../../widgets/fade_slide.dart';
import './message_bubble.dart';
import './swipe_to_reply.dart';

/// Список сообщений чата.
///
/// Умеет докручиваться до конкретного сообщения и подсвечивать его —
/// этим пользуются встроенный поиск, цитаты и переход из глобального поиска.
class ChatMessageListWidget extends StatefulWidget {
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
    required this.onSwipeReply,
  });

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
  final void Function(Message msg) onSwipeReply;

  @override
  State<ChatMessageListWidget> createState() => ChatMessageListState();
}

class ChatMessageListState extends State<ChatMessageListWidget> {
  static const Duration _freshWindow = Duration(seconds: 3);
  static const Duration _highlightDuration = Duration(milliseconds: 1800);

  final Map<int, GlobalKey> _itemKeys = {};
  int? _highlightedMessageId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  String _getDateHeader(DateTime messageDate) =>
      TimeFormatter.dateHeader(messageDate);

  GlobalKey _keyFor(int messageId) =>
      _itemKeys.putIfAbsent(messageId, GlobalKey.new);

  /// Докручивает список к сообщению [messageId] и подсвечивает его.
  ///
  /// Список обратный, а строки разной высоты (разный текст, заголовки дат),
  /// поэтому точную позицию заранее не посчитать: прыгаем по средней высоте
  /// строки, затем уточняем по уже построенным строкам и доводим
  /// `ensureVisible`, когда сообщение попало в область построения.
  Future<void> revealMessage(int messageId) async {
    if (!mounted) return;

    final index = widget.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    _highlight(messageId);

    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final total = widget.messages.length;
    final targetRow = total - 1 - index;
    var rowHeight = _averageRowHeight();

    for (var attempt = 0; attempt < 6; attempt++) {
      final offset = (targetRow * rowHeight).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      controller.jumpTo(offset);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final targetContext = _itemKeys[messageId]?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.4,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      final builtRows = _builtRows();
      if (builtRows.isEmpty) return;

      final firstRow = builtRows.first;
      final lastRow = builtRows.last;
      if (targetRow >= firstRow && targetRow <= lastRow) return;

      // Уточняем среднюю высоту по видимым строкам — она локально точнее общей.
      final builtCount = lastRow - firstRow + 1;
      if (builtCount > 0) {
        rowHeight = (controller.position.viewportDimension / builtCount).clamp(
          24.0,
          400.0,
        );
      }
    }
  }

  double _averageRowHeight() {
    final controller = widget.scrollController;
    final total = widget.messages.length;
    if (!controller.hasClients || total < 2) return 80;

    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) return 80;
    return (maxExtent / (total - 1)).clamp(24.0, 400.0);
  }

  /// Индексы строк (в координатах обратного списка), которые сейчас построены.
  List<int> _builtRows() {
    final rows = <int>[];
    _itemKeys.forEach((messageId, key) {
      if (key.currentContext == null) return;
      final index = widget.messages.indexWhere((m) => m.id == messageId);
      if (index < 0) return;
      rows.add(widget.messages.length - 1 - index);
    });
    rows.sort();
    return rows;
  }

  void _highlight(int messageId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(_highlightDuration, () {
      if (!mounted) return;
      setState(() => _highlightedMessageId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Expanded(
      child: ListView.builder(
        controller: widget.scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.messages.length + (widget.isLoadingHistory ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.messages.length && widget.isLoadingHistory) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final safeIndex = widget.messages.length - 1 - index;
          if (safeIndex < 0 || safeIndex >= widget.messages.length) {
            return const SizedBox.shrink();
          }

          final msg = widget.messages[safeIndex];
          final timeString = TimeFormatter.time(msg.createdAt);
          final status = msg.status.wire;

          Widget? dateHeader;
          final isLastMessage = index == widget.messages.length - 1;
          var isNewDay = false;

          if (!isLastMessage) {
            final prevMsg = widget.messages[widget.messages.length - 1 - (index + 1)];
            final msgDate = DateFormat(
              'yyyy-MM-dd',
              'ru_RU',
            ).format(msg.createdAt);
            final prevMsgDate = DateFormat(
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
                    color: t.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDateHeader(msg.createdAt),
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                ),
              ),
            );
          }

          Widget messageWidget;
          if (msg.isSystem) {
            messageWidget = _SystemMessageRow(
              text: msg.content,
              timeString: timeString,
            );
          } else {
            messageWidget = ChatMessageBubbleWidget(
              message: msg,
              myId: widget.myId,
              timeString: timeString,
              status: status,
              selectedCount: widget.selectedCount,
              editingMessageId: widget.editingMessageId,
              isHighlighted:
                  msg.id != null && _highlightedMessageId == msg.id,
              onTap: () => widget.onMessageTap(msg),
              onLongPress: () => widget.onMessageLongPress(msg),
              onDeleteTemp: () => widget.onDeleteForwardedMessage(msg),
              onQuoteTap: (replyTo) {
                if (replyTo.id != null) widget.onScrollToMessage(replyTo.id!);
              },
              onImageTap: widget.onImageTap,
              onFileTap: widget.onFileTap,
            );
          }

          final isFresh =
              DateTime.now().difference(msg.createdAt) < _freshWindow;
          // Свои сообщения показываем сразу: анимация проявления на светлом
          // пузыре читается как «свечение», которое затем пропадает.
          // Ключ — только время: при замене временного сообщения серверным
          // id меняется, и анимация запускалась повторно.
          final isMine = widget.myId != null && msg.sender.id == widget.myId;
          if (isFresh && !isMine && !msg.isSystem) {
            messageWidget = FadeSlideIn(
              animationKey: '${msg.timeCreate}',
              beginOffset: const Offset(0, 14),
              child: messageWidget,
            );
          }

          // Свайп-ответ не мешает выделению сообщений и пересылке.
          if (msg.id != null &&
              widget.selectedCount == 0 &&
              !msg.isSystem) {
            messageWidget = SwipeToReply(
              onReply: () => widget.onSwipeReply(msg),
              child: messageWidget,
            );
          }

          final item = isNewDay && dateHeader != null
              ? Column(children: [dateHeader, messageWidget])
              : messageWidget;

          return KeyedSubtree(
            key: msg.id != null ? _keyFor(msg.id!) : null,
            child: item,
          );
        },
      ),
    );
  }
}

/// Системное сообщение: пузырь как у входящего, но без действий и статуса.
class _SystemMessageRow extends StatelessWidget {
  const _SystemMessageRow({required this.text, required this.timeString});

  final String text;
  final String timeString;

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: BoxDecoration(
              color: t.bubbleTheirs,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeString,
                    style: TextStyle(fontSize: 11, color: t.hint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
