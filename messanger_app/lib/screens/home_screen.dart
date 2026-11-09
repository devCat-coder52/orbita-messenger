import 'dart:async';

import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/key_storage_service.dart';
import '../services/message_crypto.dart';

import '../widgets/error_dialog.dart';
import '../widgets/online_indicator.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/unread_badge.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/theme_mode_sheet.dart';
import '../widgets/empty_state_hint.dart';

import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'message_search_screen.dart';
import 'profile_screen.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../data/chat_repository.dart';
import '../utils/json_utils.dart';

import '../theme/app_theme.dart';
import '../utils/navigation.dart';

class HomeScreen extends StatefulWidget {
  final List<Message>? forwardMessages;

  const HomeScreen({super.key, this.forwardMessages});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<Chat> chats = [];

  /// Номер текущей загрузки списка: ответы со старым номером отбрасываются,
  /// чтобы не вернуть чат, который уже удалён.
  int _chatsVersion = 0;
  bool _isLoading = true;
  int? myId;
  bool _isSelectionMode = false;
  bool _isDisconnected = false;
  bool _routeSubscribed = false;
  Timer? _chatsReloadTimer;
  bool get _isForwardMode =>
      widget.forwardMessages != null && widget.forwardMessages!.isNotEmpty;

  /// В режиме пересылки сервисный чат недоступен как получатель.
  List<Chat> get _visibleChats => _isForwardMode
      ? chats.where((chat) => chat.userId > 0).toList()
      : chats;
  final Set<int> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    // Возвращаемся с любого экрана (чат, поиск, профиль) — обновляем список:
    // это чинит превью после «удалить у себя» и счётчики непрочитанных.
    _reloadChats();
  }

  Future<void> _initializeHome() async {
    final id = await AuthService.getUserId();
    if (!mounted) return;
    setState(() => myId = id);

    await SocketService.connectIfNotConnected();
    _loadChats();
    _initializeSocket();
  }

  void _initializeSocket() {
    SocketService.onMessageAdded(_onMessageAdded);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);
    SocketService.onChatCreated(_onChatCreated);
    SocketService.onChatDeleted(_onChatDeleted);

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

  bool get _isCurrentRoute {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  /// Пока поверх открыт чат, список не обновляем — обновим при возврате
  /// (см. didPopNext).
  void _reloadIfVisible() {
    if (!_isCurrentRoute) return;
    _reloadChats();
  }

  void _onMessageAdded(dynamic data) {
    _reloadIfVisible();
  }

  void _onMessageEdited(dynamic data) {
    _reloadIfVisible();
  }

  void _onMessageDeleted(dynamic data) {
    _reloadIfVisible();
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
    if (data == null) return;

    final items = data is List ? data : [data];

    for (final result in items) {
      if (result is! Map) continue;
      final chatId = asInt(result['chat_id']);
      final updatedBy = asInt(result['updated_by']);
      // Свои собственные отметки о прочтении в списке не учитываем.
      if (chatId == null || updatedBy == myId) continue;

      setState(() {
        for (final chat in chats) {
          if (chat.chatId != chatId) continue;
          if (chat.messageSender == myId) {
            chat.messageStatus = ChatMessageStatus.read;
          }
          break;
        }
      });
    }
  }

  void _onChatCreated(dynamic data) {
    _reloadChats();
  }

  Future<void> _onChatDeleted(dynamic data) async {
    final items = data is List ? data : [data];
    for (final item in items) {
      if (item is! Map) continue;
      final chatId = asInt(item['chat_id']);
      if (chatId == null) continue;

      await ChatRepository.removeCachedChat(chatId);
      if (!mounted) return;
      setState(() {
        chats.removeWhere((chat) => chat.chatId == chatId);
        _selectedChatIds.remove(chatId);
      });
    }
    _reloadChats();
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

  Future<void> _loadChats() async {
    final version = ++_chatsVersion;

    try {
      final fresh = await ChatRepository.getChats(
        onCached: (cached) async {
          if (!mounted || version != _chatsVersion) return;
          await _decryptChatPreviews(cached);
          if (!mounted || version != _chatsVersion) return;
          setState(() {
            chats = cached;
            _isLoading = false;
          });
        },
      );
      if (!mounted || version != _chatsVersion) return;

      await _decryptChatPreviews(fresh);
      if (!mounted || version != _chatsVersion) return;

      setState(() {
        chats = fresh;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted && version == _chatsVersion) {
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

    // Копия: сокетное событие chat_deleted чистит _selectedChatIds прямо
    // во время запроса, и обход исходного множества падал с
    // ConcurrentModificationError — чат удалялся, но показывалась ошибка.
    final chatIds = _selectedChatIds.toList();
    final deleted = <int>{};
    Object? failure;

    for (final chatId in chatIds) {
      try {
        await ChatService.deleteChat(chatId);
        deleted.add(chatId);
      } catch (e) {
        failure ??= e;
      }
      try {
        await ChatRepository.removeCachedChat(chatId);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      chats.removeWhere((chat) => deleted.contains(chat.chatId));
      _selectedChatIds.removeAll(chatIds);
    });
    _exitSelectionMode();

    if (failure != null) {
      ErrorDialog.show(
        context,
        'Не удалось удалить чат. Возможно, он уже удалён — обновите список.',
        details: failure,
      );
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
          final aPinned = a.isPinned ? 0 : 1;
          final bPinned = b.isPinned ? 0 : 1;
          if (aPinned != bPinned) return aPinned - bPinned;
          return (b.messageTime ?? 0).compareTo(a.messageTime ?? 0);
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

  Future<void> _muteSelectedChats() async {
    try {
      for (final chatId in _selectedChatIds) {
        final chat = chats.firstWhere((c) => c.chatId == chatId);
        await ChatService.toggleMuteChat(chatId);
        chat.toggleMute();
        ChatRepository.cacheChat(chat).ignore();
      }
      setState(() {});
      _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(
          context,
          'Не удалось изменить уведомления чатов. Попробуйте ещё раз.',
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isSelectionMode
                  ? 'Выбрано: ${_selectedChatIds.length}'
                  : _isForwardMode
                  ? 'Выберите чат'
                  : 'Чаты',
            ),
            if (_isLoading && chats.isNotEmpty) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTokens.of(context).textOnHeader,
                ),
              ),
            ],
          ],
        ),
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
                  icon: Icon(
                    _selectedChatIds.every(
                          (id) => chats.any(
                            (chat) => chat.chatId == id && chat.isMuted,
                          ),
                        )
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  tooltip: 'Без звука',
                  onPressed: _muteSelectedChats,
                ),
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
                  icon: const Icon(Icons.manage_search),
                  tooltip: 'Поиск по сообщениям',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MessageSearchScreen(),
                      ),
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Мой профиль',
                  onPressed: () {
                    final id = myId;
                    if (id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: id),
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
              onRefresh: _loadChats,
              child: _isLoading && chats.isEmpty
                  ? Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTokens.of(context).secondary,
                        ),
                      ),
                    )
                  : _visibleChats.isEmpty
                  ? EmptyStateHint(
                      icon: Icons.chat_bubble_outline,
                      title: _isForwardMode
                          ? 'Нет чатов для пересылки'
                          : 'Здесь появятся ваши чаты',
                      message: _isForwardMode
                          ? 'Сервисный чат не принимает пересланные сообщения'
                          : 'Создайте новый чат, чтобы начать диалог',
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverList.builder(
                          itemCount: _visibleChats.length,
                          itemBuilder: (context, index) {
                            var chat = _visibleChats[index];
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
                                            if (chat.isMuted)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .notifications_off_outlined,
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
                                      if (chat.messageSender == myId) ...[
                                        const SizedBox(width: 6),
                                        MessageStatusIcon(
                                          status: chat.messageStatus.name,
                                          size: 15,
                                          isMe: true,
                                        ),
                                      ],
                                      if (chat.unreadCount > 0) ...[
                                        const SizedBox(width: 8),
                                        UnreadBadge(count: chat.unreadCount),
                                      ],
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
          // Системная полоса навигации: непрозрачная, в цвет шапки.
          if (MediaQuery.paddingOf(context).bottom > 0)
            Container(
              height: MediaQuery.paddingOf(context).bottom,
              color: AppTokens.of(context).headerBackground,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatsReloadTimer?.cancel();
    routeObserver.unsubscribe(this);
    SocketService.offMessageAdded(_onMessageAdded);
    SocketService.offMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    SocketService.offChatCreated(_onChatCreated);
    SocketService.offChatDeleted(_onChatDeleted);
    SocketService.onConnectionLost = null;
    super.dispose();
  }
}
