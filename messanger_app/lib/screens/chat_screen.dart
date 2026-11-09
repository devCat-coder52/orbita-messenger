import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/message.dart';
import '../../utils/logger.dart';
import '../../services/socket_service.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/fade_slide.dart';
import '../../widgets/voice_recording_overlay.dart';
import '../../theme/app_theme.dart';

import 'chat/chat_controller.dart';
import 'chat/emoji_picker.dart';
import 'chat/header_bar.dart';
import 'chat/media_handler.dart';
import 'chat/message_actions.dart';
import 'chat/message_list.dart';
import 'chat/panel_input.dart';
import 'chat/search_bar.dart';
import 'chat/search_controller.dart';
import 'home_screen.dart';

class ChatScreen extends StatefulWidget {
  final int? userId;
  final int? chatId;
  final List<Message>? forwardMessages;

  /// Сообщение, к которому прокрутить после открытия (переход из поиска).
  final int? initialMessageId;

  const ChatScreen({
    this.userId,
    this.chatId,
    this.forwardMessages,
    this.initialMessageId,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _controller;
  late final ChatSearchController _search;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _menuButtonKey = GlobalKey();
  final GlobalKey<ChatMessageListState> _messageListKey = GlobalKey();
  bool _emojiVisible = false;

  static const _messageActions = ChatMessageActions();
  static const _mediaHandler = ChatMediaHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = ChatController(
      chatId: widget.chatId,
      userId: widget.userId,
      forwardMessages: widget.forwardMessages,
      onError: _showError,
      onScrollToBottom: _scrollToBottom,
      onInputCleared: _textController.clear,
    );

    _search = ChatSearchController(
      messages: () => _controller.messages,
      onRevealMessage: _revealMessage,
      onCacheFallback: _controller.searchCacheFallback,
    );

    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextTyping);
    _controller.initialize().then((_) => _revealInitialMessage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_onTextTyping);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// В фоне экран чата уже не открыт — возвращаем push-уведомления.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final chatId = widget.chatId;
    if (chatId == null) return;

    if (state == AppLifecycleState.resumed) {
      SocketService.enterChat(chatId);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      SocketService.exitChat(chatId);
    }
  }

  void _showError(String message, {Object? details}) {
    if (!mounted) return;
    ErrorDialog.show(context, message, details: details);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    if (_controller.shouldPrefetchHistory(
      position.pixels,
      position.maxScrollExtent,
    )) {
      _loadMoreHistory();
    }
    _controller.updateScrollState(
      pixels: position.pixels,
      maxExtent: position.maxScrollExtent,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadMoreHistory() async {
    final previousOffset = _scrollController.offset;
    final added = await _controller.loadMoreHistory();
    if (!added || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(previousOffset);
      }
    });
  }

  /// Докручивает список к сообщению и подсвечивает его.
  void _revealMessage(int messageId) {
    final found = _controller.messages.any((m) => m.id == messageId);
    if (!found) {
      _showSnack('Сообщение не найдено в загруженной истории');
      return;
    }
    _messageListKey.currentState?.revealMessage(messageId);
  }

  /// Переход из глобального поиска: ждём, пока история отрисуется.
  Future<void> _revealInitialMessage() async {
    final messageId = widget.initialMessageId;
    if (messageId == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));

    // Сообщение могло не попасть в первую страницу истории — догружаем,
    // пока не найдём его или не кончится история.
    var attempts = 0;
    while (mounted &&
        !_controller.messages.any((m) => m.id == messageId) &&
        _controller.hasMoreMessages &&
        attempts < 10) {
      final added = await _controller.loadMoreHistory();
      if (!added) break;
      attempts++;
    }

    if (!mounted) return;
    _revealMessage(messageId);
  }

  void _toggleEmoji() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _emojiVisible = !_emojiVisible);
  }

  /// Клавиатура и панель эмодзи не должны занимать место одновременно.
  void _hideEmoji() {
    if (_emojiVisible) setState(() => _emojiVisible = false);
  }

  /// Вставляет эмодзи в позицию курсора.
  void _insertEmoji(String emoji) {
    final value = _textController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, emoji);
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _onTextTyping() {
    _controller.scheduleTypingStatus(_textController.text.isNotEmpty);
  }

  void _sendMessage() => _controller.sendMessage(_textController.text);

  void _toggleSearch() => setState(_search.toggle);

  void _performSearch(String query) =>
      setState(() => _search.performSearch(query));

  void _navigateSearch(int direction) =>
      setState(() => _search.navigate(direction));

  void _onMessageTap(Message msg) {
    if (msg.isSystem) return;

    _messageActions.onMessageTap(
      context: context,
      message: msg,
      myId: _controller.myId,
      messages: _controller.messages,
      isEditingThis: _controller.editingMessageId != null,
      onReply: () => _startReply(msg),
      onEdit: () => _changeEditing(msg),
      onDelete: _showDeleteConfirmation,
      onToggleSelection: () => _controller.toggleSelection(msg),
    );
  }

  void _onMessageLongPress(Message msg) {
    if (msg.isSystem) return;
    if (_controller.selectedMessages.isNotEmpty) return;
    _controller.toggleSelection(msg);
  }

  void _startReply(Message msg) {
    if (_controller.buildReply(msg) == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _cancelReply() => _controller.cancelReply();

  void _changeEditing(Message msg) {
    final text = _controller.changeEditing(msg);
    if (text == null) return;

    _textController.text = text;
    if (text.isNotEmpty) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _showDeleteConfirmation(Message msg) {
    final chatId = _controller.chatId;
    if (chatId == null) return;

    _messageActions.showDeleteConfirmation(
      context: context,
      message: msg,
      chatId: chatId,
      myId: _controller.myId,
      onDelete: (isLocal) => _controller.deleteMessage(msg, isLocal: isLocal),
    );
  }

  Future<void> _deleteSelectedMessages() async {
    final selected = _controller.selectedMessages;
    final chatId = _controller.chatId;
    if (selected.isEmpty || chatId == null) return;

    final result = await _messageActions.deleteSelected(
      context: context,
      selectedMessages: selected,
      chatId: chatId,
      myId: _controller.myId,
      onConfirmed: _controller.removeSelectedMessages,
    );
    if (!mounted) return;

    // Отмена в диалоге: ничего не трогаем (сообщения уже могли быть
    // удалены локально, если подтверждение было).
    if (!result.confirmed) return;

    if (result.error != null) {
      _showSnack(result.error!);
      log.e(result.error!);
      return;
    }

    _controller.removeSelectedMessages();
    _controller.clearSelection();
  }

  void _exitSelectionMode() => _controller.clearSelection();

  Future<void> _forwardSelectedMessages() async {
    if (_controller.selectedMessages.isEmpty) return;

    final forwardMessages = _controller.buildForwardCopies();
    if (forwardMessages.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(forwardMessages: forwardMessages),
      ),
    );

    if (result == true && mounted) {
      _controller.clearSelection();
    }
  }

  void _deleteForwardedMessages(Message item) =>
      _controller.removeForwarded(item);

  void _cancelForwardedMessages() => _controller.cancelForwarded();

  void _exitChat() {
    if (!_controller.hasForwarded && widget.forwardMessages != null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _downloadAndOpenFile(String relativeUrl, String fileName) async {
    final error = await _mediaHandler.downloadAndOpenFile(
      relativeUrl,
      fileName,
    );
    if (error == null || !mounted) return;
    log.e(error);
    _showSnack(error);
  }

  Future<void> _startVoiceRecording() async {
    VoiceRecordingOverlay.start(context, onSent: _controller.sendVoiceMessage);
  }

  void _showChatMenu() {
    final button =
        _menuButtonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    final menuLeft = buttonPosition.dx + button.size.width - 100;
    final menuTop = buttonPosition.dy + button.size.height + 5;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(menuLeft, menuTop, 100, 10),
        Offset.zero & screenSize,
      ),
      items: [
        const PopupMenuItem(
          value: 'search',
          child: Row(
            children: [
              Icon(Icons.search, size: 20),
              SizedBox(width: 10),
              Text('Поиск сообщений'),
            ],
          ),
        ),

      ],
    ).then((value) {
      if (value == 'search') _toggleSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selectedCount = _controller.selectedMessages.length;
        final forwardedCount = _controller.forwardedMessages.length;

        return Scaffold(
          appBar: ChatBarHeaderWidget(
            user: _controller.partnerUser,
            chatStatus: _controller.chatStatus,
            selectedCount: selectedCount,
            menuButtonKey: _menuButtonKey,
            onMenuPressed: _showChatMenu,
            onCancelPressed: _exitSelectionMode,
            onDeletePressed: _deleteSelectedMessages,
            onForwardPressed: _forwardSelectedMessages,
            onBackPressed: _exitChat,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (_search.isActive)
                    ChatSearchBarWidget(
                      searchController: _search.textController,
                      hasResults: _search.results.isNotEmpty,
                      currentIndex: _search.currentIndex,
                      totalResults: _search.results.length,
                      isSearchingCache: _search.isSearchingCache,
                      onChanged: _performSearch,
                      onBackPressed: _toggleSearch,
                      onNavigateUp: () => _navigateSearch(-1),
                      onNavigateDown: () => _navigateSearch(1),
                    ),
                  ChatMessageListWidget(
                    key: _messageListKey,
                    messages: [..._controller.messages],
                    myId: _controller.myId,
                    selectedCount: selectedCount,
                    editingMessageId: _controller.editingMessageId,
                    hasMoreMessages: _controller.hasMoreMessages,
                    isLoadingHistory: _controller.isLoadingHistory,
                    scrollController: _scrollController,
                    onMessageTap: _onMessageTap,
                    onMessageLongPress: _onMessageLongPress,
                    onDeleteForwardedMessage: _deleteForwardedMessages,
                    onReplyTap: _startReply,
                    onScrollToMessage: _revealMessage,
                    onSwipeReply: _startReply,
                    onFileTap: _downloadAndOpenFile,
                    onImageTap: (imageUrl) {
                      _mediaHandler.openImageViewer(context, imageUrl);
                    },
                  ),
                  if (_emojiVisible && forwardedCount == 0)
                    EmojiPicker(onEmoji: _insertEmoji),
                  if (forwardedCount == 0)
                    _controller.isServiceChat
                        ? const _ServiceChatHint()
                        : ChatInputPanelWidget(
                            textController: _textController,
                            replyingTo: _controller.replyingTo,
                            myId: _controller.myId,
                            myName: _controller.currentUser?.name,
                            onCancelReply: _cancelReply,
                            onSendPressed: _sendMessage,
                            onPickImagePressed: _controller.pickAndSendImage,
                            onPickFilePressed: _controller.pickAndSendFile,
                            onPickRecordPressed: _startVoiceRecording,
                            onEmojiPressed: _toggleEmoji,
                            emojiActive: _emojiVisible,
                            onInputTapped: _hideEmoji,
                          )
                  else
                    ChatInputPanelWidget(
                      textController: _textController,
                      forwardCount: forwardedCount,
                      onCancelForward: _cancelForwardedMessages,
                      onSendPressed: _sendMessage,
                      onPickImagePressed: _controller.pickAndSendImage,
                      onPickFilePressed: _controller.pickAndSendFile,
                    ),
                  // Системная полоса навигации: непрозрачная, в цвет шапки.
                  if (MediaQuery.paddingOf(context).bottom > 0)
                    Container(
                      height: MediaQuery.paddingOf(context).bottom,
                      color: AppTokens.of(context).headerBackground,
                    ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 92,
                child: AnimatedScale(
                  scale:
                      (!_controller.atBottom ||
                          _controller.newMessagesCount > 0)
                      ? 1.0
                      : 0.0,
                  alignment: Alignment.bottomRight,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: IgnorePointer(
                    ignoring:
                        _controller.atBottom &&
                        _controller.newMessagesCount == 0,
                    child: _buildScrollToBottomPill(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollToBottomPill() {
    final t = AppTokens.of(context);
    final hasNew = _controller.newMessagesCount > 0;

    void handleTap() {
      HapticFeedback.lightImpact();
      _controller.markAtBottom();
      _scrollToBottom();
    }

    return FadeSlideIn(
      animationKey: hasNew ? 'new' : 'down',
      beginOffset: const Offset(0, 8),
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 3,
        shape: const CircleBorder(),
        color: t.surface,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: handleTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.surface),
            child: hasNew
                ? Center(
                    child: Text(
                      _controller.newMessagesCount > 99
                          ? '99+'
                          : '${_controller.newMessagesCount}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: t.primary,
                      ),
                    ),
                  )
                : Icon(Icons.keyboard_arrow_down, color: t.primary, size: 26),
          ),
        ),
      ),
    );
  }
}
/// Заглушка вместо поля ввода в сервисном чате.
class _ServiceChatHint extends StatelessWidget {
  const _ServiceChatHint();

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    return Container(
      width: double.infinity,
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Text(
        'Это сервисный чат — ответить на него нельзя.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: t.textSecondary),
      ),
    );
  }
}
