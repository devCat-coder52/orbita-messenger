import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
//import 'package:emoji_keyboard_flutter/emoji_keyboard_flutter.dart';

import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';

import './chat/header_bar.dart';
import './chat/media_handler.dart';
import './chat/message_list.dart';
import './chat/message_actions.dart';
import './chat/panel_forward.dart';
import './chat/panel_input.dart';
import './chat/search_bar.dart';
import './chat/search_controller.dart';

import '../widgets/error_dialog.dart';
import '../widgets/voice_recording_overlay.dart';

import '../utils/logger.dart';
import '../utils/time_formatter.dart';

import './home_screen.dart';
import '../models/member.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final int? userId;
  final int? chatId;
  final List<Message>? forwardMessages;

  const ChatScreen({this.userId, this.chatId, this.forwardMessages, super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  int? myId;
  int? userId;
  int? chatId;

  int _searchIndex = -1;

  int _messageOffset = 0;
  String chatStatus = 'загрузка...';
  //bool _showEmojiKeyboard = false;
  bool _isLoadingHistory = false;
  bool _isSearchActive = false;
  bool _hasMoreMessages = false;
  bool _animateLock = false;
  int? _editingMessageId;
  Message? _replyingTo;
  List<int> _searchResults = [];
  Timer? _statusTimer;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  DateTime? _lastSeenTime;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  late final ChatSearchController _search;

  static const _messageActions = ChatMessageActions();
  static const _mediaHandler = ChatMediaHandler();

  Member? currentUser;
  Member? partnerUser;

  final GlobalKey _menuButtonKey = GlobalKey();

  late List<Message> messages = [];
  List<Message> get _selectedMessages =>
      messages.where((msg) => msg.isSelected == true).toList();
  List<Message> get _forwardedMessages =>
      messages.where((msg) => msg.status == MessageStatus.forwarding).toList();

  final borderColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    SocketService.onReceiveMessage(_onReceiveMessage);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);
    //SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    SocketService.onUserTyping(_onUserTyping);
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextTyping);
  }

  void _onUserStatusChanged(dynamic data) {
    if (data['userId'].toString() != userId.toString()) return;

    setState(() {
      if (data['status'] == 'online') {
        chatStatus = 'в сети';
        _statusTimer?.cancel();
        setState(() {
          _lastSeenTime = null;
        });
      } else {
        final lastSeenStr = data['last_seen'];
        if (lastSeenStr != null) {
          setState(() {
            _lastSeenTime = DateTime.parse(lastSeenStr);
          });
          _updateStatusText();

          _statusTimer?.cancel();
          _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
            if (mounted && _lastSeenTime != null) {
              _updateStatusText();
            }
          });
        } else {
          chatStatus = 'был(а) давно';
        }
      }
    });
  }

  void _initializeChat() async {
    _search = ChatSearchController(
      scrollController: _scrollController,
      messages: () => messages,
    );
    if (widget.forwardMessages != null) {
      messages = [...messages, ...widget.forwardMessages!];
    }
    await _getCurrentUser();
    if (widget.chatId != null) {
      chatId = widget.chatId;
      await _loadUserData(null, chatId);
      await _joinAndLoadHistory();
    } else if (widget.userId != null) {
      userId = widget.userId;
      await _loadUserData(userId, null);
    }
  }

  Future<void> _getCurrentUser() async {
    final id = await AuthService.getUserId();
    if (id != null) {
      final userData = await UserService.getUserById(id);
      if (mounted) {
        myId = id;
        setState(() {
          currentUser = Member(
            id: id,
            name: userData['name'] ?? userData['login'],
            avatarUrl: userData['avatar_url'],
          );
        });
      }
    }
  }

  Future<void> _loadUserData(int? uId, int? cId) async {
    try {
      final userData = uId != null
          ? await UserService.getUserById(uId)
          : await UserService.getUserByChat(cId!);

      if (mounted) {
        setState(() {
          partnerUser = Member(
            id: userData['id'],
            name: userData['name'] ?? userData['login'] ?? 'Чат',
            avatarUrl: userData['avatar_url'],
            gender: userData['gender'],
          );

          userId = userData['id'];

          if (userData['is_online'] == true) {
            chatStatus = 'в сети';
          } else if (userData['last_seen'] != null) {
            setState(() {
              _lastSeenTime = DateTime.parse(userData['last_seen']);
            });
            _updateStatusText();

            _statusTimer?.cancel();
            _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
              if (mounted && _lastSeenTime != null) _updateStatusText();
            });
          } else {
            chatStatus = 'был(а) давно';
          }
        });
      }
    } catch (e) {
      log.e(e);
    }
  }

  Future<void> _joinAndLoadHistory() async {
    await SocketService.connectIfNotConnected();
    if (myId != null) {
      SocketService.emit('user_connected', myId);
    }
    SocketService.joinChat(chatId!);
    _loadHistory();
  }

  void _onMessageSent() {
    setState(() {
      _animateLock = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) setState(() => _animateLock = false);
    });
  }

  void _onReceiveMessage(dynamic data) async {
    final incoming = Message.fromJson(Map<String, dynamic>.from(data));
    int existingIndex = messages.indexWhere(
      (m) => m.timeCreate == incoming.timeCreate,
    );

    if (existingIndex != -1) {
      setState(() {
        messages[existingIndex] = messages[existingIndex].copyWith(
          id: incoming.id,
          status: MessageStatus.sent,
        );
      });
    }

    if (incoming.sender.id != myId && existingIndex == -1) {
      setState(() {
        messages.add(incoming);
      });
    }
    /*if (data['sender']['id'] != myId) {
      if (existingIndex != -1) {
        setState(() {
          messages[existingIndex]['status'] = 'sent';
        });
      } else {
        data['status'] = data['status'] ?? 'sent';
        String finalContent = data['content'];
        if (data['is_encrypted'] == true) {
          final myPrivateKey = await KeyStorageService.getPrivateKey();

          if (myPrivateKey != null) {
            try {
              finalContent = CryptoService.decryptMessage(
                finalContent,
                myPrivateKey,
              );
            } catch (e) {
              finalContent = '[Ошибка расшифровки]';
            }
          }
        }
        data['content'] = finalContent;
        setState(() {
          messages.add(data);
        });
      }
    }*/
    SocketService.markAsRead(chatId!, myId!);
  }

  void _onMessageEdited(dynamic data) {
    if (data['chat_id'] != chatId) return;

    setState(() {
      final index = messages.indexWhere((m) => m.id == data['id']);
      messages[index] = messages[index].copyWith(
        content: data['content'].toString(),
        isEdited: true,
      );
    });
  }

  void _onMessageDeleted(dynamic data) {
    if (data['chat_id'] != chatId) return;
    setState(() {
      final index = messages.indexWhere((m) => m.id == data['message_id']);
      if (index != -1) messages.removeAt(index);
    });
  }

  void _onMessageStatusUpdated(dynamic data) {
    if (data['chat_id'] == chatId) {
      setState(() {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].sender.id == myId) {
            messages[i] = messages[i].copyWith(status: MessageStatus.read);
          }
        }
      });
    }
  }

  void _onUserTyping(dynamic data) {
    if (data['chat_id'] != chatId) return;

    final isTyping = data['is_typing'] == true;

    setState(() {
      if (isTyping) {
        chatStatus = 'печатает...';

        _typingTimer?.cancel();

        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              chatStatus = 'онлайн';
            });
          }
        });
      } else {
        chatStatus = 'онлайн';
      }
    });
  }

  void _onTextTyping() {
    if (chatId == null || partnerUser == null || partnerUser!.name.isEmpty) {
      return;
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      final isTyping = _textController.text.isNotEmpty;
      SocketService.sendTypingStatus(chatId!, partnerUser!.name, isTyping);
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (_hasMoreMessages &&
        !_isLoadingHistory &&
        position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreHistory();
    }
  }

  void _toggleSearch() {
    setState(() => _search.toggle());
  }

  void _performSearch(String query) {
    setState(() => _search.performSearch(query));
  }

  void _navigateSearch(int direction) {
    setState(() => _search.navigate(direction));
  }

  void _loadHistory() async {
    if (chatId != null) {
      setState(() => _isLoadingHistory = true);
      try {
        final history = await ChatService.fetchMessages(chatId!);
        /*final data = await ChatService.fetchMessages(chatId!);
        final messagesList = List<Map<String, dynamic>>.from(data['messages']);
        final myPrivateKey = await KeyStorageService.getPrivateKey();
        for (var msg in messagesList) {
          String content = msg['content'];
          if (msg['is_encrypted'] == true && myPrivateKey != null) {
            try {
              content = CryptoService.decryptMessage(content, myPrivateKey);
            } catch (e) {
              content = '[Ошибка чтения]';
            }
          }
          msg['content'] = content;
        }*/
        setState(() {
          messages = [...history.messages, ...messages];
          _hasMoreMessages = history.hasMore;
          _isLoadingHistory = false;
        });
        SocketService.markAsRead(chatId!, myId!);
      } catch (e) {
        if (mounted) {
          ErrorDialog.show(context, 'ChatScreen: Ошибка загрузки истории: $e');
        }
      } finally {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingHistory || !_hasMoreMessages) return;

    setState(() => _isLoadingHistory = true);

    try {
      final previousScrollOffset = _scrollController.offset;
      final history = await ChatService.fetchMessages(
        chatId!,
        offset: _messageOffset + 50,
        limit: 50,
      );
      final newMessages = history.messages;
      _hasMoreMessages = history.hasMore;
      /*final newMessages = List<Map<String, dynamic>>.from(data['messages']);
      final myPrivateKey = await KeyStorageService.getPrivateKey();
      for (var msg in newMessages) {
        String content = msg['content'];
        if (msg['is_encrypted'] == true && myPrivateKey != null) {
          try {
            content = CryptoService.decryptMessage(content, myPrivateKey);
          } catch (e) {
            content = '[Ошибка чтения]';
          }
        }
        msg['content'] = content;
      }

      _hasMoreMessages = data['hasMore'] ?? false;*/
      _messageOffset += newMessages.length;

      if (mounted && newMessages.isNotEmpty) {
        setState(() {
          messages.insertAll(0, newMessages);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(previousScrollOffset);
          }
        });
      }
    } catch (e) {
      log.e('Ошибка подгрузки истории: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _sendMessage() async {
    final timeCreate = DateTime.now().millisecondsSinceEpoch;
    if (_forwardedMessages.isNotEmpty) {
      final originals = _forwardedMessages.toList();
      final localMessages = [
        for (final msg in originals)
          msg.copyWith(
            timeCreate: timeCreate,
            status: MessageStatus.sending,
            reply: null,
          ),
      ];
      for (var i = 0; i < originals.length; i++) {
        _replaceMessage(originals[i], localMessages[i]);
      }
      for (final msg in localMessages) {
        try {
          await SocketService.sendMessage(
            msg.content,
            chatId!,
            currentUser!,
            null,
            msg.forward,
            timeCreate,
            imageUrl: msg.imageUrl,
            fileUrl: msg.fileUrl,
            fileName: msg.fileName,
            fileSize: msg.fileSize,
          );
          _onMessageSent();
        } catch (e) {
          if (!mounted) return;
          ErrorDialog.show(context, 'Не удалось отправить сообщение: $e');
          _replaceMessage(msg, msg.copyWith(status: MessageStatus.error));
        }
      }
      return;
    }

    final content = _textController.text;
    if (content.isEmpty) return;

    if (_editingMessageId != null) {
      await SocketService.editMessage(_editingMessageId!, content);
      setState(() {
        _editingMessageId = null;
        _replyingTo = null;
        _textController.clear();
      });
      return;
    }
    final replyTo = _replyingTo;

    if (chatId == null) {
      try {
        chatId = await ChatService.createChatWith(userId!);
        await SocketService.connectIfNotConnected();
        SocketService.joinChat(chatId!);
      } catch (e) {
        if (!mounted) return;
        ErrorDialog.show(context, 'ChatScreen: Ошибка создания чата: $e');
        return;
      }
    }

    final tempMessage = Message(
      sender: currentUser!,
      content: content,
      timeCreate: timeCreate,
      status: MessageStatus.sending,
      reply: replyTo?.toJson(),
    );

    setState(() {
      messages.add(tempMessage);
      _textController.clear();
      _replyingTo = null;
    });

    try {
      await SocketService.sendMessage(
        content,
        chatId!,
        currentUser!,
        replyTo,
        null,
        timeCreate,
      );
      _onMessageSent();
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'Не удалось отправить сообщение: $e');
      _replaceMessage(
        tempMessage,
        tempMessage.copyWith(status: MessageStatus.error),
      );
    }
  }

  void _replaceMessage(Message old, Message updated) {
    setState(() {
      final index = messages.indexOf(old);
      if (index != -1) messages[index] = updated;
    });
  }

  Future<void> _pickAndSendImage() async {
    if (currentUser == null) return;
    final picked = await _mediaHandler.pickImage(sender: currentUser!);
    if (picked == null || !mounted) return;

    final tempMsg = picked.tempMessage;
    setState(() => messages.add(tempMsg));

    try {
      final uploaded = await ChatService.sendImage(
        chatId!,
        picked.file,
        tempMsg,
      );
      if (!mounted) return;
      _replaceMessage(
        tempMsg,
        tempMsg.copyWith(
          id: uploaded.id,
          imageUrl: uploaded.imageUrl,
          isTemp: false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      ErrorDialog.show(context, 'Ошибка отправки фото: $e');
    }
  }

  void _updateStatusText() {
    final prefix = partnerUser != null && partnerUser!.gender == 'М'
        ? 'был'
        : (partnerUser != null && partnerUser!.gender == 'Ж'
              ? 'была'
              : 'был(а)');

    if (_lastSeenTime == null) {
      chatStatus = '$prefix давно';
      return;
    }

    final now = DateTime.now();
    final timeStr = TimeFormatter.time(_lastSeenTime!);

    String relativeStr;
    if (TimeFormatter.isSameDay(_lastSeenTime!, now)) {
      final diff = now.difference(_lastSeenTime!);
      if (diff.inMinutes < 1) {
        relativeStr = 'только что';
      } else if (diff.inHours < 1) {
        relativeStr = '${diff.inMinutes} мин. назад';
      } else {
        relativeStr = 'сегодня в $timeStr';
      }
    } else if (TimeFormatter.isSameDay(
      _lastSeenTime!,
      now.subtract(const Duration(days: 1)),
    )) {
      relativeStr = 'вчера в $timeStr';
    } else {
      relativeStr =
          '${_lastSeenTime!.day} ${TimeFormatter.monthsGenitive[_lastSeenTime!.month]} в $timeStr';
    }

    setState(() => chatStatus = '$prefix $relativeStr');
  }

  void _onMessageTap(Message msg) {
    _messageActions.onMessageTap(
      context: context,
      message: msg,
      messages: messages,
      isEditingThis: _editingMessageId != null,
      onReply: () => _startReply(msg),
      onEdit: () => _changeEditing(msg),
      onDelete: _showDeleteConfirmation,
      onToggleSelection: () =>
          _messageActions.toggleSelection(msg, () => setState(() {})),
    );
  }

  void _onMessageLongPress(Message msg) {
    if (_selectedMessages.isNotEmpty) return;
    _messageActions.toggleSelection(msg, () => setState(() {}));
  }

  void _exitSelectionMode() {
    _messageActions.clearSelection(messages, () => setState(() {}));
  }

  void _changeEditing(Message msg) {
    final result = _messageActions.prepareEditing(
      message: msg,
      currentEditingId: _editingMessageId,
      textController: _textController,
    );
    if (result == null) return;
    if (result) {
      setState(() => _editingMessageId = null);
      return;
    }
    setState(() {
      _editingMessageId = msg.id;
      _replyingTo = null;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _showChatMenu() {
    final RenderBox button =
        _menuButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.of(context).size;

    final double menuLeft = buttonPosition.dx + button.size.width - 100;
    final double menuTop = buttonPosition.dy + button.size.height + 5;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(menuLeft, menuTop, 100, 10),
        Offset.zero & screenSize,
      ),
      items: [
        PopupMenuItem(
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
              Icon(Icons.block, size: 20, color: Colors.red),
              SizedBox(width: 10),
              Text('Заблокировать', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'search') {
        _toggleSearch();
      } /*else if (value == 'block') {
        
      }*/
    });
  }

  void _showDeleteConfirmation(Message msg) {
    _messageActions.showDeleteConfirmation(
      context: context,
      message: msg,
      chatId: chatId!,
      myId: myId,
      onBeforeDelete: () {
        if (_editingMessageId == msg.id) {
          setState(() {
            _editingMessageId = null;
            _textController.clear();
          });
        }
        SocketService.deleteMessage(msg.id!, chatId!, null);
      },
      onLocalDeleted: () {
        setState(() {
          messages.removeWhere((m) => m.id == msg.id);
        });
        SocketService.deleteMessage(msg.id!, chatId!, myId);
      },
    );
  }

  void _deleteSelectedMessages() async {
    if (mounted) {
      final error = await _messageActions.deleteSelected(
        context: context,
        selectedMessages: _selectedMessages,
        chatId: chatId!,
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
          log.e(error);
        }
        return;
      }
    }

    setState(() {
      messages.removeWhere((m) => m.isSelected && m.id != null);
    });

    _exitSelectionMode();
  }

  void _forwardSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;

    final forwardMessages = _messageActions.buildForwardCopies(
      selectedMessages: _selectedMessages,
      sender: currentUser!,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(forwardMessages: forwardMessages),
      ),
    );

    if (result == true && mounted) {
      _exitSelectionMode();
    }
  }

  void _exitChat() async {
    if (_forwardedMessages.isEmpty && widget.forwardMessages != null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      Navigator.pop(context);
    }
  }

  void _deleteForwardedMessages(Message item) async {
    setState(() {
      messages.remove(item);
    });
  }

  void _cancelForwardedMessages() async {
    setState(() {
      messages.removeWhere((msg) => msg.isForwarding);
    });
  }

  void _startReply(Message msg) {
    final replyTo = _messageActions.startReply(msg);
    if (replyTo == null) return;
    setState(() {
      _replyingTo = replyTo;
      _editingMessageId = null;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _scrollToRepliedMessage(int messageId) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сообщение не найдено в загруженной истории'),
          duration: Duration(seconds: 2),
        ),
      );
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

  Future<int?> _ensureChat() async {
    if (chatId != null) return chatId;
    try {
      chatId = await ChatService.createChatWith(userId!);
      await SocketService.connectIfNotConnected();
      SocketService.joinChat(chatId!);
      return chatId;
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, 'ChatScreen: Ошибка создания чата: $e');
      }
      return null;
    }
  }

  Future<void> _pickAndSendFile() async {
    if (currentUser == null) return;
    final picked = await _mediaHandler.pickFile(
      sender: currentUser!,
      context: context,
    );
    if (picked == null || !mounted) return;

    final id = await _ensureChat();
    if (id == null || !mounted) return;

    final tempMsg = picked.tempMessage;
    final fileName = tempMsg.fileName ?? '';
    setState(() => messages.add(tempMsg));

    try {
      final uploaded = await ChatService.sendFile(
        id,
        picked.file,
        tempMsg,
        displayName: fileName,
      );
      if (!mounted) return;
      _replaceMessage(
        tempMsg,
        tempMsg.copyWith(
          id: uploaded.id ?? tempMsg.id,
          fileUrl: uploaded.fileUrl,
          fileName: uploaded.fileName ?? fileName,
          fileSize: uploaded.fileSize ?? tempMsg.fileSize,
          isTemp: false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      ErrorDialog.show(context, 'Ошибка отправки файла: $e');
    }
  }

  Future<void> _downloadAndOpenFile(String relativeUrl, String fileName) async {
    final error = await _mediaHandler.downloadAndOpenFile(
      relativeUrl,
      fileName,
    );
    if (error != null && mounted) {
      log.e(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _startVoiceRecording() async {
    VoiceRecordingOverlay.start(context, onSent: _sendVoiceMessage);
  }

  Future<void> _sendVoiceMessage(File file, int durationSeconds) async {
    if (chatId == null || currentUser == null) return;
    final tempMsg = Message(
      sender: currentUser!,
      voiceUrl: 'temp:${file.path}',
      voiceDurationSeconds: durationSeconds,
      timeCreate: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.sending,
      isTemp: true,
    );

    setState(() => messages.add(tempMsg));

    try {
      final uploaded = await ChatService.sendVoice(
        chatId!,
        file,
        durationSeconds,
        tempMsg,
      );
      if (!mounted) return;
      _replaceMessage(
        tempMsg,
        tempMsg.copyWith(
          id: uploaded.id ?? tempMsg.id,
          voiceUrl: uploaded.voiceUrl ?? tempMsg.voiceUrl,
          timeCreate: uploaded.timeCreate,
          status: uploaded.status,
          isTemp: false,
        ),
      );
      _onMessageSent();
    } catch (e) {
      if (!mounted) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      ErrorDialog.show(context, 'Ошибка отправки голосового: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatBarHeaderWidget(
        user: partnerUser,
        chatStatus: chatStatus,
        animateLock: _animateLock,
        selectedCount: _selectedMessages.length,
        menuButtonKey: _menuButtonKey,
        onMenuPressed: _showChatMenu,
        onCancelPressed: _exitSelectionMode,
        onDeletePressed: _deleteSelectedMessages,
        onForwardPressed: _forwardSelectedMessages,
        onBackPressed: _exitChat,
      ),
      body: Column(
        children: [
          if (_search.isActive)
            ChatSearchBarWidget(
              searchController: _search.textController,
              hasResults: _search.results.isNotEmpty,
              currentIndex: _search.currentIndex,
              totalResults: _search.results.length,
              onChanged: _performSearch,
              onBackPressed: _toggleSearch,
              onNavigateUp: () => _navigateSearch(-1),
              onNavigateDown: () => _navigateSearch(1),
            ),
          ChatMessageListWidget(
            messages: [...messages],
            myId: myId,
            selectedCount: _selectedMessages.length,
            editingMessageId: _editingMessageId,
            hasMoreMessages: _hasMoreMessages,
            isLoadingHistory: _isLoadingHistory,
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
          if (_forwardedMessages.isEmpty)
            ChatInputPanelWidget(
              textController: _textController,
              borderColor: borderColor,
              replyingTo: _replyingTo,
              myId: myId,
              myName: currentUser?.name,
              onCancelReply: _cancelReply,
              onSendPressed: _sendMessage,
              onPickImagePressed: _pickAndSendImage,
              onPickFilePressed: _pickAndSendFile,
              onPickRecordPressed: _startVoiceRecording,
            )
          else
            ChatForwardPanelWidget(
              messageCount: _forwardedMessages.length,
              onCancel: _cancelForwardedMessages,
              onSend: _sendMessage,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _typingTimer?.cancel();
    _textController.removeListener(_onTextTyping);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _searchController.dispose();
    SocketService.offReceiveMessage(_onReceiveMessage);
    SocketService.offMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    SocketService.offUserTyping(_onUserTyping);
    super.dispose();
  }
}
