import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/message.dart';
import '../../utils/logger.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/fade_slide.dart';
import '../../widgets/voice_recording_overlay.dart';
import '../../theme/app_theme.dart';

import 'chat/chat_controller.dart';
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

  const ChatScreen({this.userId, this.chatId, this.forwardMessages, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller;
  late final ChatSearchController _search;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _menuButtonKey = GlobalKey();

  static const _messageActions = ChatMessageActions();
  static const _mediaHandler = ChatMediaHandler();

  @override
  void initState() {
    super.initState();

    _controller = ChatController(
      chatId: widget.chatId,
      userId: widget.userId,
      forwardMessages: widget.forwardMessages,
      onError: _showError,
      onScrollToBottom: _scrollToBottom,
      onInputCleared: _textController.clear,
    );

    _search = ChatSearchController(
      scrollController: _scrollController,
      messages: () => _controller.messages,
      onCacheFallback: _controller.searchCacheFallback,
    );

    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextTyping);
    _controller.initialize();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextTyping);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _search.dispose();
    _controller.dispose();
    super.dispose();
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

  void _scrollToRepliedMessage(int messageId) {
    final messages = _controller.messages;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      _showSnack('Сообщение не найдено в загруженной истории');
      return;
    }
    if (!_scrollController.hasClients) return;

    final reversedIndex = messages.length - 1 - index;
    final target = (reversedIndex * 80.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
    _messageActions.onMessageTap(
      context: context,
      message: msg,
      messages: _controller.messages,
      isEditingThis: _controller.editingMessageId != null,
      onReply: () => _startReply(msg),
      onEdit: () => _changeEditing(msg),
      onDelete: _showDeleteConfirmation,
      onToggleSelection: () => _controller.toggleSelection(msg),
    );
  }

  void _onMessageLongPress(Message msg) {
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

    final error = await _messageActions.deleteSelected(
      context: context,
      selectedMessages: selected,
      chatId: chatId,
    );
    if (!mounted) return;

    if (error != null) {
      _showSnack(error);
      log.e(error);
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
        PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              Icon(Icons.block, size: 20, color: AppTokens.of(context).error),
              const SizedBox(width: 10),
              Text(
                'Заблокировать',
                style: TextStyle(color: AppTokens.of(context).error),
              ),
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
                    onScrollToMessage: _scrollToRepliedMessage,
                    onFileTap: _downloadAndOpenFile,
                    onImageTap: (imageUrl) {
                      _mediaHandler.openImageViewer(context, imageUrl);
                    },
                  ),
                  if (forwardedCount == 0)
                    ChatInputPanelWidget(
                      textController: _textController,
                      replyingTo: _controller.replyingTo,
                      myId: _controller.myId,
                      myName: _controller.currentUser?.name,
                      onCancelReply: _cancelReply,
                      onSendPressed: _sendMessage,
                      onPickImagePressed: _controller.pickAndSendImage,
                      onPickFilePressed: _controller.pickAndSendFile,
                      onPickRecordPressed: _startVoiceRecording,
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
