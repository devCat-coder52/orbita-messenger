import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
import 'chat_screen.dart';
import 'search_users_screen.dart';
import 'profile_screen.dart';
import '../widgets/error_dialog.dart';
import '../widgets/online_indicator.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? forwardMessages;

  const HomeScreen({super.key, this.forwardMessages});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Chat> chats = [];
  int? myId;
  bool _isSelectionMode = false;
  Set<int> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  void _onReceiveMessage(dynamic data) {
    _loadChats();
  }

  Future<void> _initializeHome() async {
    final id = await AuthService.getUserId();
    if (!mounted) return;
    setState(() => myId = id);

    await SocketService.connectIfNotConnected();
    if (myId != null) {
      SocketService.emit('user_connected', myId!);
    }
    _loadChats();

    SocketService.onReceiveMessage(_onReceiveMessage);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
  }

  void _onUserStatusChanged(dynamic data) {
    log.i('HomeScreen: вызываем _onUserStatusChanged $data');
    final userId = data['userId'];
    final status = data['status'];

    setState(() {
      for (var chat in chats) {
        if (chat.userId == userId) {
          chat.isOnline = status == 'online' ? true : false;
          break;
          //chat['last_seen'] = data['last_seen'] ?? chat['last_seen'];
        }
      }
    });
  }

  void _onMessageStatusUpdated(dynamic data) {
    final chatId = data['chat_id'];
    /*setState(() {
      final index = chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        chats[index].lastMessageStatus = 'read';
      }
    });*/
  }

  void _loadChats() async {
    try {
      final fetchedChats = await ChatService.fetchChats(null);
      final myPrivateKey = await KeyStorageService.getPrivateKey();
      for (var chat in fetchedChats) {
        if (chat.messageType == 'media') {
          chat.messageText = 'Фотография';
        } else {
          if (chat.messageText != null) {
            String content = chat.messageText!;
            /*if (chat.messageIsEncrypted == true && myPrivateKey != null) {
              try {
                content = CryptoService.decryptMessage(content, myPrivateKey);
              } catch (e) {
                content = '[Ошибка чтения]';
              }
            }*/
            chat.messageText = content;
          }
        }
      }
      setState(() {
        chats = fetchedChats;
      });
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, 'HomeScreen: Ошибка загрузки чатов: $e');
      }
    }
  }

  String _formatTime(int? messageTime) {
    if (messageTime == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(messageTime);
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  void _enterSelectionMode(int chatId) {
    setState(() {
      _isSelectionMode = true;
      _selectedChatIds.add(chatId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _toggleChat(int chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удаление чатов'),
        content: Text(
          'Вы уверены, что хотите удалить выбранные чаты: ${_selectedChatIds.length}? Все сообщения будут удалены безвозвратно. \n\nЭто действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      for (var chatId in _selectedChatIds) {
        await ChatService.deleteChat(chatId);
      }
      setState(() {
        chats.removeWhere((c) => _selectedChatIds.contains(c.chatId));
      });
      _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, 'HomeScreen: Ошибка удаления чатов: $e');
      }
    }
  }

  Future<void> _pinSelectedChats() async {
    try {
      for (var chatId in _selectedChatIds) {
        final chat = chats.firstWhere((c) => c.chatId == chatId);
        await ChatService.togglePinChat(chatId);
        chat.isPinned = !chat.isPinned;
      }
      setState(() {
        chats.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return 0;
        });
      });
      _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, 'HomeScreen: Ошибка закрепления чатов: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('Выбрано: ${_selectedChatIds.length}')
            : Text('Чаты'),
        leading: _isSelectionMode
            ? IconButton(icon: Icon(Icons.close), onPressed: _exitSelectionMode)
            : null,

        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.push_pin),
                  onPressed: _pinSelectedChats,
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _deleteSelectedChats,
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchChatsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: myId!),
                      ),
                    );
                  },
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadChats();
        },
        child: chats.isEmpty
            ? Center(
                child: Text(
                  'У вас еще не создан ни один диалог',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  var chat = chats[index];
                  final isSelected = _selectedChatIds.contains(chat.chatId);
                  return Opacity(
                    opacity: _isSelectionMode && !isSelected ? 0.5 : 1.0,
                    child: ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withOpacity(0.2),
                      onLongPress: () {
                        if (_isSelectionMode) {
                          _toggleChat(chat.chatId!);
                        } else {
                          _enterSelectionMode(chat.chatId!);
                        }
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleChat(chat.chatId!);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatScreen(chatId: chat.chatId!),
                            ),
                          );
                        }
                      },
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            backgroundImage: chat.avatarUrl != null
                                ? NetworkImage(
                                    '${dotenv.env['BASE_URL']}/${chat.avatarUrl}',
                                  )
                                : null,
                            child:
                                (chat.avatarUrl == null ||
                                    chat.avatarUrl!.isEmpty)
                                ? Text(
                                    (chat.avatarUrl ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: OnlineIndicator(
                              isOnline: chat.isOnline == true,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: -5,
                              top: -5,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(chat.userName),
                                if (chat.isPinned)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(chat.messageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (chat.messageSender == myId ? 'Вы: ' : '') +
                                  (chat.messageText ?? 'Нет сообщений'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (chat.unreadCount > 0)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  chat.unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    SocketService.offReceiveMessage(_onReceiveMessage);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    super.dispose();
  }
}
