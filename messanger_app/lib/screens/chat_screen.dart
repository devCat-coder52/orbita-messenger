import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/profile_service.dart';
import '../services/key_storage_service.dart';
//import 'package:emoji_keyboard_flutter/emoji_keyboard_flutter.dart';
import '../widgets/error_dialog.dart';
import '../utils/logger.dart';
import 'package:image_picker/image_picker.dart';
import './photo_viewer_screen.dart';
import './home_screen.dart';
import 'dart:async';
import 'dart:io';
import './chat/app_bar.dart';
import './chat/chat_search_bar.dart';
import './chat/chat_message_list.dart';
import './chat/panel_forward.dart';
import './chat/panel_input.dart';
import '../models/member.dart';

class ChatScreen extends StatefulWidget {
  final int? userId;
  final int? chatId;
  final List<Map<String, dynamic>>? forwardMessages;

  const ChatScreen({this.userId, this.chatId, this.forwardMessages, super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  int? myId;
  int? userId;
  int? chatId;
  String? userName;
  String? userAvatar;
  int _messageOffset = 0;
  String _searchQuery = '';
  String chatStatus = 'загрузка...';
  //bool _showEmojiKeyboard = false;
  bool _isLoadingHistory = false;
  bool _isSearchActive = false;
  bool _isMenuOpen = false;
  bool _hasMoreMessages = false;
  bool _animateLock = false;
  int? _editingMessageId;
  Map<String, dynamic>? _replyingTo;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  Timer? _statusTimer;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  DateTime? _lastSeenTime;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Member? currentUser;
  Member? partnerUser;

  final GlobalKey _menuButtonKey = GlobalKey();

  late List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> get _selectedMessages =>
      messages.where((msg) => msg['is_selected'] == true).toList();
  List<Map<String, dynamic>> get _forwardedMessages =>
      messages.where((msg) => msg['status'] == 'forwarding').toList();

  static const primaryColor = Color(0xFF2C3E50);
  static const secondaryColor = Color(0xFF3498DB);
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
    if (widget.forwardMessages != null) {
      messages = [
        ...messages,
        ...List<Map<String, dynamic>>.from(widget.forwardMessages!),
      ];
    }
    await _getCurrenUser();
    if (widget.chatId != null) {
      chatId = widget.chatId;
      await _loadUserData(null, chatId);
      await _joinAndLoadHistory();
    } else if (widget.userId != null) {
      userId = widget.userId;
      await _loadUserData(userId, null);
    }
  }

  Future<void> _getCurrenUser() async {
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
          print(userData);
          partnerUser = Member(
            id: userData['id'],
            name: userData['name'] ?? userData['login'] ?? 'Чат',
            avatarUrl: userData['avatar_url'],
            gender: userData['gender'],
          );

          userName = userData['name'] ?? userData['login'] ?? 'Чат';
          userAvatar = userData['avatar_url'];
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

    if (data['sender']['id'] != myId) {
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
          if (msg['sender']['id'] == /*data['updated_by']*/ myId) {
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
    if (chatId == null || partnerUser == null || partnerUser!.name.isEmpty)
      return;
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
          messages = [...messagesList, ...messages];
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
    final timeCreate = DateTime.now().millisecondsSinceEpoch;
    if (_forwardedMessages.isNotEmpty) {
      List<Map<String, dynamic>> localMessages = _forwardedMessages;
      setState(() {
        for (var msg in _forwardedMessages) {
          msg['time_create'] = timeCreate.toString();
          msg['status'] = 'sending';
        }
      });
      log.i(localMessages);
      for (var msg in localMessages) {
        try {
          await SocketService.sendMessage(
            msg['content'],
            chatId!,
            currentUser!,
            msg['reply'],
            msg['forward'],
            timeCreate,
            imageUrl: msg['image_url'],
          );
          _onMessageSent();
        } catch (e) {
          if (!mounted) return;
          ErrorDialog.show(context, 'Не удалось отправить сообщение: $e');
          setState(() => msg['status'] = 'error');
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

    setState(() {
      messages.add({
        'content': content,
        'sender': currentUser!.toMap(),
        'reply': replyTo,
        'time_create': timeCreate.toString(),
        'status': 'sending',
        'is_selected': false,
      });
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
      setState(() => messages.last['status'] = 'error');
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
      'sender': currentUser!.toMap(),
      'time_create': DateTime.now().millisecondsSinceEpoch.toString(),
      'status': 'sending',
      'is_selected': false,
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
          chatStatus = '$prefix только что';
        } else if (diff.inHours < 1) {
          chatStatus = '$prefix ${diff.inMinutes} мин. назад';
        } else {
          chatStatus = '$prefix сегодня в $timeStr';
        }
      } else if (messageDay == yesterday) {
        chatStatus = '$prefix вчера в $timeStr';
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
        chatStatus =
            '$prefix ${_lastSeenTime!.day} ${months[_lastSeenTime!.month]} в $timeStr';
      }
    });
  }

  void _onMessageTap(Map<String, dynamic> msg) {
    if (_forwardedMessages.isNotEmpty) {
      return;
    } else if (_selectedMessages.isNotEmpty) {
      _toggleMessageSelection(msg);
    } else {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.reply, color: secondaryColor),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.pop(context);
                    _startReply(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
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
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Удалить',
                    style: TextStyle(color: Colors.red),
                  ),
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
  }

  void _onMessageLongPress(Map<String, dynamic> msg) {
    if (_selectedMessages.isNotEmpty) return;
    _toggleMessageSelection(msg);
  }

  void _exitSelectionMode() {
    setState(() {
      for (var msg in _selectedMessages) {
        msg['is_selected'] = false;
      }
    });
  }

  void _toggleMessageSelection(Map<String, dynamic> msg) {
    setState(() {
      msg['is_selected'] = !msg['is_selected'];
    });
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
      _replyingTo = null;
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

  void _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Удаление сообщений'),
          content: Text(
            'Вы уверены, что хотите удалить выбранные сообщения: ${_selectedMessages.length}? Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      for (var msg in _selectedMessages) {
        await SocketService.deleteMessage(msg['id'], chatId!, null);
      }
      setState(() {
        _exitSelectionMode();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
        log.e('Ошибка при удалении: $e');
      }
    }
  }

  void _forwardSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;
    int timeCreate = DateTime.now().millisecondsSinceEpoch;

    var forwardMessages = _selectedMessages.map((message) {
      log.i(message['sender']);
      return {
        ...message,
        'time_create': timeCreate.toString(),
        'status': 'forwarding',
        'sender': currentUser!.toMap(),
        'is_selected': false,
        'forward': message['sender'],
      };
    }).toList();

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

  void _deleteForwardedMessages(Map<String, dynamic> item) async {
    setState(() {
      messages.remove(item);
    });
  }

  void _cancelForwardedMessages() async {
    setState(() {
      messages.removeWhere((msg) => msg['status'] == 'forwarding');
    });
  }

  void _startReply(Map<String, dynamic> msg) {
    if (msg['id'] == null || msg['status'] == 'forwarding') return;
    setState(() {
      _replyingTo = Map<String, dynamic>.from(msg);
      _editingMessageId = null;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _scrollToRepliedMessage(int messageId) {
    final index = messages.indexWhere(
      (m) => m['id'].toString() == messageId.toString(),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBarWidget(
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
          if (_forwardedMessages.isEmpty)
            ChatInputPanelWidget(
              textController: _textController,
              borderColor: borderColor,
              replyingTo: _replyingTo,
              myId: myId,
              myName: currentUser?.name,
              onCancelReply: _cancelReply,
              onSendPressed: _sendMessage,
              onAddPressed: _pickAndSendImage,
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
