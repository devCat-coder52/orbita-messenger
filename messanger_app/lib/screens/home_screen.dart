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
import '../widgets/theme_mode_sheet.dart';
import '../widgets/empty_state_hint.dart';

import 'chat_screen.dart';
import 'search_users_screen.dart';
import 'new_chat_screen.dart';
import 'profile_screen.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../data/chat_repository.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final List<Message>? forwardMessages;

  const HomeScreen({super.key, this.forwardMessages});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Chat> chats = [];
  bool _isLoading = true;
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
          setState(() {
            chats = cached;
            _isLoading = false;
          });
        },
      );
      await _decryptChatPreviews(fresh);
      if (!mounted) return;
      setState(() {
        chats = fresh;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorDialog.show(
          context,
          'Не удалось загрузить список чатов. Попробуйте обновить список.',
          details: e,
        );
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
          _selectedChatIds.length == 1
              ? 'Удалить этот чат? Все сообщения в нём будут удалены безвозвратно.\n\nЭто действие нельзя отменить.'
              : 'Удалить выбранные чаты (${_selectedChatIds.length})? Все сообщения в них будут удалены безвозвратно.\n\nЭто действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.of(context).error,
              foregroundColor: AppTokens.of(context).textOnAccent,
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
        ErrorDialog.show(
          context,
          'Не удалось удалить выбранные чаты. Попробуйте ещё раз.',
          details: e,
        );
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
        ErrorDialog.show(
          context,
          'Не удалось изменить закрепление чатов. Попробуйте ещё раз.',
          details: e,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isSelectionMode || _isForwardMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatScreen()),
                );
              },
              tooltip: 'Новый чат',
              backgroundColor: AppTokens.of(context).accent,
              foregroundColor: AppTokens.of(context).textOnAccent,
              child: const Icon(Icons.edit_outlined),
            ),
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
                  icon: const Icon(Icons.push_pin),
                  tooltip: 'Закрепить',
                  onPressed: _pinSelectedChats,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Удалить',
                  onPressed: _deleteSelectedChats,
                ),
              ]
            : [
                const ThemeQuickToggle(),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Поиск по чатам',
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
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Мой профиль',
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
              color: AppTokens.of(context).warningBackground,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 16,
                    color: AppTokens.of(context).warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Нет соединения — сообщения уйдут автоматически',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.of(context).warning,
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
              child: _isLoading && chats.isEmpty
                  ? const SkeletonList()
                  : chats.isEmpty
                  ? EmptyStateHint(
                      icon: Icons.chat_bubble_outline,
                      title: 'Здесь появятся ваши чаты',
                      message:
                          'Найдите собеседника через поиск, чтобы начать диалог',
                    )
                  : CustomScrollView(
                      slivers: [
                        if (_isLoading && chats.isNotEmpty)
                          const SliverToBoxAdapter(
                            child: SkeletonBanner(height: 36),
                          ),
                        SliverList.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            var chat = chats[index];
                            final isSelected = _selectedChatIds.contains(
                              chat.chatId,
                            );
                            return Semantics(
                              button: true,
                              selected: isSelected,
                              label:
                                  'Чат с ${chat.userName}, '
                                  '${chat.unreadCount > 0 ? '${chat.unreadCount} непрочитанных' : 'без непрочитанных'}',
                              child: Opacity(
                                opacity: _isSelectionMode && !isSelected
                                    ? 0.5
                                    : 1.0,
                                child: ListTile(
                                  selected: isSelected,
                                  selectedTileColor: AppTokens.of(
                                    context,
                                  ).secondary.withValues(alpha: 0.15),
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
                                            forwardMessages:
                                                widget.forwardMessages,
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
                                            decoration: BoxDecoration(
                                              color: AppTokens.of(
                                                context,
                                              ).secondary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: AppTokens.of(
                                                context,
                                              ).textOnAccent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              chat.userName,
                                              style: TextStyle(
                                                color: AppTokens.of(
                                                  context,
                                                ).textPrimary,
                                              ),
                                            ),
                                            if (chat.isPinned)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Icon(
                                                  Icons.push_pin,
                                                  size: 14,
                                                  color: AppTokens.of(
                                                    context,
                                                  ).textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        chat.formattedTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTokens.of(
                                            context,
                                          ).textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              if (chat.messageSender == myId)
                                                TextSpan(
                                                  text: 'Вы: ',
                                                  style: TextStyle(
                                                    color: AppTokens.of(
                                                      context,
                                                    ).textSecondary,
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
                              ),
                            );
                          },
                        ),
                      ],
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
