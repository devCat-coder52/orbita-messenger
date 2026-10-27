import 'dart:async';

import 'package:flutter/material.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/key_storage_service.dart';
import '../services/message_crypto.dart';

import '../widgets/error_dialog.dart';
import '../widgets/online_indicator.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/unread_badge.dart';

import 'chat_screen.dart';
import 'search_users_screen.dart';
import 'profile_screen.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../data/chat_repository.dart';

import '../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  final List<Message>? forwardMessages;

  const HomeScreen({super.key, this.forwardMessages});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Chat> chats = [];
  int? myId;
  bool _isSelectionMode = false;
  bool _isDisconnected = false;
  Timer? _chatsReloadTimer;
  bool get _isForwardMode =>
      widget.forwardMessages != null && widget.forwardMessages!.isNotEmpty;
  final Set<int> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    final id = await AuthService.getUserId();
    if (!mounted) return;
    setState(() => myId = id);

    await SocketService.connectIfNotConnected();
    //_loadChats();
    _initializeSocket();
  }

  void _initializeSocket() {
    SocketService.onMessageAdded(_onMessageAdded);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);

    SocketService.onConnectionLost = () {
      if (mounted) setState(() => _isDisconnected = true);
    };
    SocketService.addOnConnectionRestored(_onConnectionRestored);

    if (!SocketService.isConnected) {
      setState(() => _isDisconnected = true);
    }
  }

  void _reloadChats() {
    _chatsReloadTimer?.cancel();
    _chatsReloadTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadChats();
    });
  }

  void _onConnectionRestored() {
    if (!mounted) return;
    setState(() => _isDisconnected = false);
    _reloadChats();
  }

  void _onMessageAdded(dynamic data) {
    _reloadChats();
  }

  void _onMessageEdited(dynamic data) {
    _reloadChats();
  }

  void _onMessageDeleted(dynamic data) {
    _reloadChats();
  }

  void _onUserStatusChanged(dynamic data) {
    if (data == null) return;

    final items = data is List ? data : [data];

    for (final result in items) {
      if (result is! Map) continue;
      if (result['userId'] != myId) {
        setState(() {
          for (var chat in chats) {
            if (chat.userId == result['userId']) {
              chat.isOnline = result['status'] == 'online';
              break;
            }
          }
        });
      }
    }
  }

  void _onMessageStatusUpdated(dynamic data) {
    /*if (data == null) return;

    final items = data is List ? data : [data];

    for (final result in items) {
      if (result is! Map) continue;
      final chatId = result['chat_id'];
      setState(() {
        final index = chats.indexWhere((c) => c.id == chatId);
        if (index != -1) {
          chats[index].lastMessageStatus = 'read';
        }
      });
    }*/
  }

  Future<void> _decryptChatPreviews(List<Chat> list) async {
    final myPrivateKey = await KeyStorageService.getPrivateKey();
    for (var chat in list) {
      if (chat.messageForwarder != null) {
        chat.messageText = 'Пересланное сообщение';
      } else if (chat.messageType == ChatMessageType.image) {
        chat.messageText = 'Фотография';
      } else {
        if (chat.messageText != null) {
          chat.messageText = MessageCrypto.display(
            chat.messageText!,
            myPrivateKey,
          );
        }
      }
    }
  }

  void _loadChats() async {
    try {
      final fresh = await ChatRepository.getChats(
        onCached: (cached) async {
          if (!mounted) return;
          await _decryptChatPreviews(cached);
          setState(() => chats = cached);
        },
      );
      await _decryptChatPreviews(fresh);
      if (!mounted) return;
      setState(() {
        chats = fresh;
      });
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, 'HomeScreen: Ошибка загрузки чатов: $e');
      }
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
        await ChatRepository.removeCachedChat(chatId);
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
        chat.togglePin();
        ChatRepository.cacheChat(chat).ignore();
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
            : _isForwardMode
            ? Text('Выберите чат')
            : Text('Чаты'),
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: () => _exitSelectionMode(),
              )
            : _isForwardMode
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, false),
              )
            : null,

        actions: _isForwardMode
            ? null
            : _isSelectionMode
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
      body: Column(
        children: [
          if (_isDisconnected)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  Text(
                    'Нет соединения — сообщения уйдут автоматически',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
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
                        final isSelected = _selectedChatIds.contains(
                          chat.chatId,
                        );
                        return Opacity(
                          opacity: _isSelectionMode && !isSelected ? 0.5 : 1.0,
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withValues(
                              alpha: 0.2,
                            ),
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
                                    builder: (context) => ChatScreen(
                                      chatId: chat.chatId!,
                                      forwardMessages: widget.forwardMessages,
                                    ),
                                  ),
                                );
                              }
                            },
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ChatAvatar(
                                  avatarUrl: chat.avatarUrl,
                                  fallbackName: chat.userName,
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
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
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
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                          ),
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
                                  chat.formattedTime,
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
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        if (chat.messageSender == myId)
                                          const TextSpan(
                                            text: 'Вы: ',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        TextSpan(text: chat.previewText),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                UnreadBadge(count: chat.unreadCount),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatsReloadTimer?.cancel();
    SocketService.offMessageAdded(_onMessageAdded);
    SocketService.offMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    SocketService.onConnectionLost = null;
    super.dispose();
  }
}
