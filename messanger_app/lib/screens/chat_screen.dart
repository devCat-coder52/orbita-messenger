import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
//import 'package:emoji_keyboard_flutter/emoji_keyboard_flutter.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/encryption_status_icon.dart';
import '../widgets/error_dialog.dart';
import '../utils/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './photo_viewer_screen.dart';
import './profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:io';

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
  int _messageOffset = 0;
  String userStatus = 'загрузка...';
  bool _showEmojiKeyboard = false;
  bool _isLoadingHistory = false;
  bool _hasMoreMessages = false;
  bool _animateLock = false;
  int? _editingMessageId;
  Timer? _statusTimer;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  DateTime? _lastSeenTime;
  late List<Map<String, dynamic>> messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const primaryColor = Color(0xFF2C3E50);
  static const secondaryColor = Color(0xFF3498DB);
  final borderColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _getMyId();
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

  void _getMyId() async {
    final id = await AuthService.getUserId();
    if (mounted) setState(() => myId = id);
  }

  void _initializeChat() async {
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
      (m) =>
          m['content'] == data['content'] &&
          m['sender_id'] == data['sender_id'] &&
          m['created_at'] == data['created_at'],
    );
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
    }
    if (existingIndex != -1) {
      setState(() {
        messages[existingIndex]['id'] = data['id'];
      });
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
          if (msg['sender_id'] == data['updated_by']) {
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

  void _loadHistory() async {
    if (chatId != null) {
      setState(() => _isLoadingHistory = true);
      try {
        final data = await ChatService.fetchMessages(chatId!);
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
        if (msg['is_encrypted'] == true && myPrivateKey != null) {
          try {
            content = CryptoService.decryptMessage(content, myPrivateKey);
          } catch (e) {
            content = '[Ошибка чтения]';
          }
        }
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
      final recipientKey = await UserService.getPublicKey(userId!);
      if (recipientKey == null) {
        if (!mounted) return;
        ErrorDialog.show(
          context,
          'Не удалось получить ключ шифрования. Попробуйте позже.',
        );
        return;
      }
      final encrContent = CryptoService.encryptMessage(content, recipientKey);
      if (_editingMessageId != null) {
        await SocketService.editMessage(_editingMessageId!, encrContent);
        setState(() {
          _editingMessageId = null;
          _textController.clear();
        });
        return;
      }
      String createdAt = DateTime.now().toUtc().toIso8601String();
      String finalCreatedAt = createdAt.replaceAllMapped(
        RegExp(r'(\.\d{3})\d*Z'),
        (Match m) => '${m.group(1)}Z',
      );
      if (chatId == null) {
        try {
          chatId = await UserService.createChatWith(userId!);
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
        'created_at': finalCreatedAt,
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
          finalCreatedAt,
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
      'created_at': DateTime.now().toUtc().toIso8601String(),
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
    if (_lastSeenTime == null) {
      userStatus = 'был(а) давно';
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
          userStatus = 'был(а) только что';
        } else if (diff.inHours < 1) {
          userStatus = 'был(а) ${diff.inMinutes} мин. назад';
        } else {
          userStatus = 'был(а) сегодня в $timeStr';
        }
      } else if (messageDay == yesterday) {
        userStatus = 'был(а) вчера в $timeStr';
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
            'был(а) ${_lastSeenTime!.day} ${months[_lastSeenTime!.month]} в $timeStr';
      }
    });
  }

  String _getDateHeader(String isoDate) {
    final messageDate = DateTime.parse(isoDate);
    final now = DateTime.now();

    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDay == today) {
      return 'Сегодня';
    } else if (messageDay == yesterday) {
      return 'Вчера';
    } else {
      const months = [
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
      return '${messageDate.day} ${months[messageDate.month - 1]} ${messageDate.year}';
    }
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
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Удалить для меня'),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Удалить для всех'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: userId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: userId!),
                    ),
                  );
                }
              : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: userAvatar != null && userAvatar!.isNotEmpty
                    ? NetworkImage('${dotenv.env['BASE_URL']}/$userAvatar')
                    : null,
                backgroundColor: Colors.grey[600],
                child: userAvatar == null || userAvatar!.isEmpty
                    ? Text(
                        userName?.isNotEmpty == true
                            ? userName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName ?? 'Чат',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userStatus,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              EncryptionStatus(
                isEncrypted: true,
                triggerAnimation: _animateLock,
              ),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.symmetric(vertical: 4),
              itemCount: messages.length + (_hasMoreMessages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && _hasMoreMessages) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final safeIndex = messages.length - 1 - index;
                if (safeIndex < 0 || safeIndex >= messages.length) {
                  return const SizedBox.shrink();
                }
                var msg = messages[safeIndex];
                bool isMe = msg['sender_id'] == myId;
                DateTime dateTime = DateTime.parse(msg['created_at']).toLocal();
                String timeString =
                    '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                String status = msg['status'] ?? 'sent';
                Widget? dateHeader;
                Widget messageContent;
                bool isLastMessage = index == messages.length - 1;
                bool isNewDay = false;

                if (!isLastMessage) {
                  var prevMsg = messages[messages.length - 1 - (index + 1)];
                  String currentDate = _getDateHeader(msg['created_at']);
                  String prevDate = _getDateHeader(prevMsg['created_at']);
                  if (currentDate != prevDate) {
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getDateHeader(msg['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (msg['image_url'] != null &&
                    msg['image_url'].toString().isNotEmpty) {
                  final isLocal = msg['is_temp'] != null && msg['is_temp'];
                  final displayUrl = isLocal
                      ? msg['image_url'].toString().replaceFirst('temp:', '')
                      : '${dotenv.env['BASE_URL']}${msg['image_url']}';

                  Widget imageWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isLocal
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(
                                File(displayUrl),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : CachedNetworkImage(
                            imageUrl: displayUrl,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            placeholder: (_, __) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[300],
                            ),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.broken_image, size: 50),
                          ),
                  );

                  imageWidget = GestureDetector(
                    onTap: () {
                      if (!isLocal) {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    PhotoViewerScreen(imageUrl: displayUrl),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      }
                    },
                    child: imageWidget,
                  );
                  messageContent = imageWidget;
                } else {
                  messageContent = Text(msg['content']);
                }
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: isMe ? () => _showMessageOptions(msg) : null,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? (msg['id'] != null &&
                                      _editingMessageId == msg['id']
                                  ? Color(0xFFB3E5FC)
                                  : Color(0xFFE3F2FD))
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          messageContent,
                          SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: 4),
                              if (msg['is_edited'] == true)
                                Text(
                                  'ред.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              SizedBox(width: 4),
                              MessageStatusIcon(
                                status: status,
                                size: 14,
                                isMe: isMe,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
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
                    icon: const Icon(Icons.add, color: primaryColor),
                    onPressed: _pickAndSendImage,
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
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      maxLines: null,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение...',
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
                              onPressed: _sendMessage,
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
    SocketService.offReceiveMessage(_onReceiveMessage);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    SocketService.offUserTyping(_onUserTyping);
    super.dispose();
  }
}
