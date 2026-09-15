import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
//import 'package:emoji_keyboard_flutter/emoji_keyboard_flutter.dart';
import '../widgets/error_dialog.dart';
import '../utils/logger.dart';
import 'package:image_picker/image_picker.dart';
import './photo_viewer_screen.dart';
import 'dart:async';
import 'dart:io';
import './chat/chat_app_bar.dart';
import './chat/chat_search_bar.dart';
import './chat/chat_message_list.dart';
import './chat/chat_input_field.dart';

class ChatScreen extends StatefulWidget {
  final int? userId;
  final int? chatId;
  final String? userName;
  final String? userAvatar;

  const ChatScreen({
    this.userId,
    this.chatId,
    this.userName,
    this.userAvatar,
    super.key,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  int? myId;
  int? userId;
  int? chatId;
  String? userName;
  String? userAvatar;
  String? userGender;
  int _messageOffset = 0;
  String _searchQuery = '';
  String userStatus = 'загрузка...';
  //bool _showEmojiKeyboard = false;
  bool _isLoadingHistory = false;
  bool _isSearchActive = false;
  bool _isMenuOpen = false;
  bool _hasMoreMessages = false;
  bool _animateLock = false;
  int? _editingMessageId;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  Timer? _statusTimer;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  DateTime? _lastSeenTime;
  late List<Map<String, dynamic>> messages = [];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _menuButtonKey = GlobalKey();

  static const primaryColor = Color(0xFF2C3E50);
  static const secondaryColor = Color(0xFF3498DB);
  final borderColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadHistory();
    SocketService.onReceiveMessage(_onReceiveMessage);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    SocketService.onUserTyping(_onUserTyping);
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextTyping);
  }

  void _onUserStatusChanged(dynamic data) {
    if (data['userId'].toString() != userId.toString()) return;

    setState(() {
      if (data['status'] == 'online') {
        userStatus = 'в сети';
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
          userStatus = 'был(а) давно';
        }
      }
    });
  }

  void _initializeChat() async {
    final id = await AuthService.getUserId();
    if (mounted) setState(() => myId = id);
    if (widget.chatId != null) {
      chatId = widget.chatId;
      await _loadUserData(null, chatId);
      await _joinAndLoadHistory();
    } else if (widget.userId != null) {
      userId = widget.userId;
      await _loadUserData(userId, null);
    }
  }

  void _onMessageSent() {
    setState(() {
      _animateLock = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) setState(() => _animateLock = false);
    });
  }

  Future<void> _loadUserData(int? uId, int? cId) async {
    try {
      final userData = uId != null
          ? await UserService.getUserById(uId)
          : await UserService.getUserByChat(cId!);

      if (mounted) {
        setState(() {
          userName = userData['name'] ?? userData['login'] ?? 'Чат';
          userAvatar = userData['avatar_url'];
          userId = userData['id'];
          userGender = userData['gender'];

          if (userData['is_online'] == true) {
            userStatus = 'в сети';
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
            userStatus = 'был(а) давно';
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

  void _onReceiveMessage(dynamic data) async {
    int existingIndex = messages.indexWhere(
      (m) => m['time_create'] == data['time_create'],
    );

    if (existingIndex != -1) {
      setState(() {
        messages[existingIndex]['id'] = data['id'];
        messages[existingIndex]['status'] = 'sent';
      });
    }

    if (data['sender_id'] != myId) {
      if (existingIndex != -1) {
        setState(() {
          messages[existingIndex]['status'] = 'sent';
        });
      } else {
        data['status'] = data['status'] ?? 'sent';
        String finalContent = data['content'];
        if (data['is_encrypted'] == true) {
          final myPrivateKey = await KeyStorageService.getPrivateKey();

          /*if (myPrivateKey != null) {
            try {
              finalContent = CryptoService.decryptMessage(
                finalContent,
                myPrivateKey,
              );
            } catch (e) {
              finalContent = '[Ошибка расшифровки]';
            }
          }*/
        }
        data['content'] = finalContent;
        setState(() {
          messages.add(data);
        });
      }
    }
    SocketService.markAsRead(chatId!, myId!);
  }

  void _onMessageEdited(dynamic data) {
    if (data['chat_id'] != chatId) return;

    setState(() {
      final index = messages.indexWhere((m) => m['id'] == data['id']);
      if (index != -1) {
        messages[index]['content'] = data['content'];
        messages[index]['is_edited'] = true;
      }
    });
  }

  void _onMessageDeleted(dynamic data) {
    if (data['chat_id'] != chatId) return;
    setState(() {
      final index = messages.indexWhere((m) => m['id'] == data['message_id']);
      messages.removeAt(index);
    });
  }

  void _onMessageStatusUpdated(dynamic data) {
    if (data['chat_id'] == chatId) {
      setState(() {
        for (var msg in messages) {
          if (msg['sender_id'] == /*data['updated_by']*/ myId) {
            msg['status'] = 'read';
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
        userStatus = 'печатает...';

        _typingTimer?.cancel();

        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              userStatus = 'онлайн';
            });
          }
        });
      } else {
        userStatus = 'онлайн';
      }
    });
  }

  void _onTextTyping() {
    if (chatId == null || userName == null) return;
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      final isTyping = _textController.text.isNotEmpty;
      SocketService.sendTypingStatus(chatId!, userName!, isTyping);
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
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchQuery = '';
        _searchResults = [];
        _currentSearchIndex = -1;
        _searchController.clear();
      }
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchResults = [];
      _currentSearchIndex = -1;

      if (query.isEmpty) return;

      for (int i = 0; i < messages.length; i++) {
        final content = messages[i]['content'] ?? '';
        if (content.toLowerCase().contains(query.toLowerCase())) {
          _searchResults.add(i);
        }
      }

      if (_searchResults.isNotEmpty) {
        _currentSearchIndex = _searchResults.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToMessage(_searchResults[_currentSearchIndex]);
        });
      }
    });
  }

  void _navigateSearch(int direction) {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex += direction;
      if (_currentSearchIndex < 0) {
        _currentSearchIndex = _searchResults.length - 1;
      } else if (_currentSearchIndex >= _searchResults.length) {
        _currentSearchIndex = 0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMessage(_searchResults[_currentSearchIndex]);
    });
  }

  void _scrollToMessage(int messageIndex) {
    if (!_scrollController.hasClients) return;
    final totalMessages = messages.length;
    final reversedIndex = totalMessages - 1 - messageIndex;
    final scrollPosition = reversedIndex * 80.0;

    _scrollController.animateTo(
      scrollPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _loadHistory() async {
    if (chatId != null) {
      setState(() => _isLoadingHistory = true);
      try {
        final data = await ChatService.fetchMessages(chatId!);
        final messagesList = List<Map<String, dynamic>>.from(data['messages']);
        final myPrivateKey = await KeyStorageService.getPrivateKey();
        for (var msg in messagesList) {
          String content = msg['content'];
          /*if (msg['is_encrypted'] == true && myPrivateKey != null) {
            try {
              content = CryptoService.decryptMessage(content, myPrivateKey);
            } catch (e) {
              content = '[Ошибка чтения]';
            }
          }*/
          msg['content'] = content;
        }
        setState(() {
          messages = messagesList;
          _hasMoreMessages = data['hasMore'] ?? false;
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
      final data = await ChatService.fetchMessages(
        chatId!,
        offset: _messageOffset + 50,
        limit: 50,
      );
      final newMessages = List<Map<String, dynamic>>.from(data['messages']);
      final myPrivateKey = await KeyStorageService.getPrivateKey();
      for (var msg in newMessages) {
        String content = msg['content'];
        /*if (msg['is_encrypted'] == true && myPrivateKey != null) {
          try {
            content = CryptoService.decryptMessage(content, myPrivateKey);
          } catch (e) {
            content = '[Ошибка чтения]';
          }
        }*/
        msg['content'] = content;
      }

      _hasMoreMessages = data['hasMore'] ?? false;
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
    if (_textController.text.isNotEmpty) {
      final content = _textController.text;
      /*final recipientKey = await UserService.getPublicKey(userId!);
      if (recipientKey == null) {
        if (!mounted) return;
        ErrorDialog.show(
          context,
          'Не удалось получить ключ шифрования. Попробуйте позже.',
        );
        return;
      }*/
      final encrContent =
          content; // CryptoService.encryptMessage(content, recipientKey);
      if (_editingMessageId != null) {
        await SocketService.editMessage(_editingMessageId!, encrContent);
        setState(() {
          _editingMessageId = null;
          _textController.clear();
        });
        return;
      }
      int timeCreate = DateTime.now().millisecondsSinceEpoch;
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
      final tempMsg = {
        'content': content,
        'sender_id': myId,
        'time_create': timeCreate.toString(),
        'status': 'sending',
      };

      setState(() {
        messages.add(tempMsg);
        _textController.clear();
      });
      try {
        await SocketService.sendMessage(
          encrContent,
          chatId!,
          userName!,
          timeCreate,
        );
        _onMessageSent();
      } catch (e) {
        if (!mounted) return;
        ErrorDialog.show(context, 'Не удалось отправить сообщение: $e');
        setState(() {
          final idx = messages.indexOf(tempMsg);
          if (idx != -1) messages[idx]['status'] = 'error';
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    final tempMsg = {
      'content': '',
      'image_url': 'temp:${pickedFile.path}',
      'sender_id': myId,
      'time_create': DateTime.now().millisecondsSinceEpoch.toString(),
      'status': 'sending',
      'is_temp': true,
    };

    setState(() => messages.add(tempMsg));
    final idx = messages.indexOf(tempMsg);

    try {
      final message = await ChatService.sendImage(
        chatId!,
        File(pickedFile.path),
        tempMsg,
      );
      setState(() {
        if (idx != -1) {
          messages[idx]['is_temp'] = false;
          messages[idx]['image_url'] = message['image_url'];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = messages.indexOf(tempMsg);
        if (idx != -1) messages[idx]['status'] = 'error';
      });
      ErrorDialog.show(context, 'Ошибка отправки фото: $e');
    }
  }

  void _updateStatusText() {
    final prefix = userGender == 'М'
        ? 'был'
        : (userGender == 'Ж' ? 'была' : 'был(а)');

    if (_lastSeenTime == null) {
      userStatus = '$prefix давно';
      return;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(
      _lastSeenTime!.year,
      _lastSeenTime!.month,
      _lastSeenTime!.day,
    );

    String timeStr =
        '${_lastSeenTime!.hour}:${_lastSeenTime!.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (messageDay == today) {
        final diff = now.difference(_lastSeenTime!);
        if (diff.inMinutes < 1) {
          userStatus = '$prefix только что';
        } else if (diff.inHours < 1) {
          userStatus = '$prefix ${diff.inMinutes} мин. назад';
        } else {
          userStatus = '$prefix сегодня в $timeStr';
        }
      } else if (messageDay == yesterday) {
        userStatus = '$prefix вчера в $timeStr';
      } else {
        const months = [
          '',
          'января',
          'февраля',
          'марта',
          'апреля',
          'мая',
          'июня',
          'июля',
          'августа',
          'сентября',
          'октября',
          'ноября',
          'декабря',
        ];
        userStatus =
            '$prefix ${_lastSeenTime!.day} ${months[_lastSeenTime!.month]} в $timeStr';
      }
    });
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.edit),
                title: Text(
                  _editingMessageId != null
                      ? 'Отменить редактирование'
                      : 'Редактировать',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _changeEditing(msg);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(msg);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _changeEditing(Map<String, dynamic> msg) {
    if (_editingMessageId == msg['id']) {
      setState(() {
        _editingMessageId = null;
        _textController.clear();
      });
      return;
    }
    _textController.text = msg['content'];
    setState(() {
      _editingMessageId = msg['id'];
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _showChatMenu() {
    setState(() => _isMenuOpen = true);

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
      setState(() => _isMenuOpen = false);

      if (value == 'search') {
        _toggleSearch();
      } /*else if (value == 'block') {
        
      }*/
    });
  }

  void _showDeleteConfirmation(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Удаление сообщения'),
          content: Text('Вы хотите удалить это сообщение?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_editingMessageId == msg['id']) {
                  setState(() {
                    _editingMessageId = null;
                    _textController.clear();
                  });
                }
                SocketService.deleteMessage(msg['id'], chatId!, myId);
                setState(() {
                  final index = messages.indexWhere(
                    (m) => m['id'] == msg['id'],
                  );
                  messages.removeAt(index);
                });
              },
              child: Text(
                'Удалить для меня',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_editingMessageId == msg['id']) {
                  setState(() {
                    _editingMessageId = null;
                    _textController.clear();
                  });
                }
                SocketService.deleteMessage(msg['id'], chatId!, null);
              },
              child: Text(
                'Удалить для всех',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBarWidget(
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        userStatus: userStatus,
        animateLock: _animateLock,
        onMenuPressed: _showChatMenu,
        menuButtonKey: _menuButtonKey,
      ),
      body: Column(
        children: [
          if (_isSearchActive)
            ChatSearchBarWidget(
              searchController: _searchController,
              hasResults: _searchResults.isNotEmpty,
              currentIndex: _currentSearchIndex,
              totalResults: _searchResults.length,
              onChanged: _performSearch,
              onBackPressed: _toggleSearch,
              onNavigateUp: () => _navigateSearch(-1),
              onNavigateDown: () => _navigateSearch(1),
            ),
          ChatMessageListWidget(
            messages: messages,
            myId: myId,
            editingMessageId: _editingMessageId,
            hasMoreMessages: _hasMoreMessages,
            isLoadingHistory: _isLoadingHistory,
            scrollController: _scrollController,
            onMessageLongPress: _showMessageOptions,
            onImageTap: (imageUrl) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      PhotoViewerScreen(imageUrl: imageUrl),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
          ChatInputFieldWidget(
            textController: _textController,
            borderColor: borderColor,
            onSendPressed: _sendMessage,
            onAddPressed: _pickAndSendImage,
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
