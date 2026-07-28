import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
//import 'package:emoji_keyboard_flutter/emoji_keyboard_flutter.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/error_dialog.dart';
import '../utils/logger.dart';
import 'dart:async';

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
  bool _hasMoreMessages = true;
  Timer? _statusTimer;
  DateTime? _lastSeenTime;
  late List<Map<String, dynamic>> messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getMyId();
    _initializeChat();
    SocketService.onReceiveMessage(_onReceiveMessage);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    _scrollController.addListener(_onScroll);
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

  void _onReceiveMessage(dynamic data) {
    if (data['sender_id'] != myId) {
      int existingIndex = messages.indexWhere(
        (m) =>
            m['content'] == data['content'] &&
            m['sender_id'] == data['sender_id'] &&
            m['created_at'] == data['created_at'],
      );

      if (existingIndex != -1) {
        setState(() {
          messages[existingIndex]['status'] = 'sent';
        });
      } else {
        data['status'] = data['status'] ?? 'sent';
        setState(() {
          messages.add(data);
        });
      }
    }
    SocketService.markAsRead(chatId!, myId!);
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
      try {
        final data = await ChatService.fetchMessages(chatId!);
        setState(() {
          messages = List<Map<String, dynamic>>.from(data['messages']);
        });
        SocketService.markAsRead(chatId!, myId!);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoadingHistory = false);
        ErrorDialog.show(context, 'ChatScreen: Ошибка загрузки истории: $e');
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
      debugPrint('Ошибка подгрузки истории: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _sendMessage() async {
    if (_textController.text.isNotEmpty) {
      final content = _textController.text;
      final createdAt = DateTime.now().toUtc().toIso8601String();
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
      final tempMessage = {
        'content': content,
        'sender_id': myId,
        'created_at': createdAt,
        'status': 'sending',
      };

      setState(() {
        messages.add(tempMessage);
        _textController.clear();
      });
      try {
        await SocketService.sendMessage(content, chatId!, userName!, createdAt);
      } catch (e) {
        if (!mounted) return;
        ErrorDialog.show(context, 'Не удалось отправить сообщение: $e');
        setState(() {
          final idx = messages.indexOf(tempMessage);
          if (idx != -1) messages[idx]['status'] = 'error';
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: userAvatar != null && userAvatar!.isNotEmpty
                  ? NetworkImage('http://192.168.0.6:3000/$userAvatar')
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
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
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

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?dateHeader,
                    Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 8,
                        ),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFFE3F2FD)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(msg['content']),
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
                  ],
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.emoji_emotions),
                        onPressed: () {
                          setState(() {
                            _showEmojiKeyboard = !_showEmojiKeyboard;
                          });
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Введите сообщение...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
                /*if (_showEmojiKeyboard)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 250,
                        child: EmojiKeyboard(
                          onEmojiChanged: (emoji) {
                            setState(() {
                              _textController.text += emoji;
                            });
                          },
                        ),
                      ),
                    ),*/
              ],
            ),
          ),
        ],
      ),
      /*body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse:
                      true, // <-- добавим reverse для новых сообщений внизу
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg =
                        messages[messages.length -
                            1 -
                            index]; // <-- инвертируем индекс
                    bool isMe = msg['sender_id'] == myId;
                    DateTime dateTime = DateTime.parse(msg['created_at']);
                    String timeString =
                        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                    String status = msg['status'] ?? 'sent';
                    Widget statusWidget = Container();
                    if (isMe) {
                      if (status == 'sending') {
                        statusWidget = Text(
                          '⏳',
                          style: TextStyle(fontSize: 12),
                        );
                      } else if (status == 'sent') {
                        statusWidget = Text(
                          '✅✅',
                          style: TextStyle(fontSize: 12),
                        );
                      } else if (status == 'read') {
                        statusWidget = Text(
                          '🔵🔵',
                          style: TextStyle(fontSize: 12),
                        ); // синие
                      }
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[200] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(msg['content']),
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
                                statusWidget,
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.emoji_emotions),
                      onPressed: () {
                        setState(() {
                          _showEmojiKeyboard = !_showEmojiKeyboard;
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Введите сообщение...',
                        ),
                      ),
                    ),
                    IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
                  ],
                ),
              ),
            ],
          ),
          if (_showEmojiKeyboard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 250,
                child: EmojiKeyboard(
                  emojiController: _textController,
                  onEmojiChanged: (emoji) {
                    setState(() {
                      _textController.text += emoji;
                    });
                  },
                  showEmojiKeyboard: true,
                  emojiKeyboardHeight: 250,
                ),
              ),
            ),
        ],
      ),*/
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SocketService.offReceiveMessage(_onReceiveMessage);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    super.dispose();
  }
}
