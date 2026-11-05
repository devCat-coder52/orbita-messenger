import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/chat_repository.dart';
import '../../models/member.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/key_storage_service.dart';
import '../../services/message_crypto.dart';
import '../../services/socket_service.dart';
import '../../services/user_service.dart';
import '../../utils/json_utils.dart';
import '../../utils/logger.dart';
import '../../utils/time_formatter.dart';
import 'media_handler.dart';
import 'message_actions.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    int? chatId,
    int? userId,
    this.forwardMessages,
    this.onError,
    this.onScrollToBottom,
    this.onInputCleared,
  }) : _chatId = chatId,
       _userId = userId;

  final void Function(String message, {Object? details})? onError;

  final void Function()? onScrollToBottom;

  final void Function()? onInputCleared;

  final List<Message>? forwardMessages;

  static const _mediaHandler = ChatMediaHandler();
  static const _messageActions = ChatMessageActions();

  static const _pageSize = 50;
  static const _historyPrefetchThreshold = 200.0;
  static const _bottomThreshold = 80.0;

  int? _chatId;
  int? _userId;
  int? _myId;

  final List<Message> _messages = [];
  Member? _currentUser;
  Member? _partnerUser;

  String _chatStatus = 'загрузка...';
  bool _isLoadingHistory = false;
  bool _hasMoreMessages = false;
  bool _atBottom = true;
  int _newMessagesCount = 0;
  int _messageOffset = 0;
  int? _editingMessageId;
  Message? _replyingTo;

  Timer? _statusTimer;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  DateTime? _lastSeenTime;
  bool _disposed = false;
  bool _refreshing = false;

  int? get chatId => _chatId;
  int? get userId => _userId;
  int? get myId => _myId;

  List<Message> get messages => _messages;
  Member? get currentUser => _currentUser;
  Member? get partnerUser => _partnerUser;

  String get chatStatus => _chatStatus;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get atBottom => _atBottom;
  int get newMessagesCount => _newMessagesCount;
  int? get editingMessageId => _editingMessageId;
  Message? get replyingTo => _replyingTo;

  List<Message> get selectedMessages =>
      _messages.where((msg) => msg.isSelected).toList();

  List<Message> get forwardedMessages =>
      _messages.where((msg) => msg.status == MessageStatus.forwarding).toList();

  bool get hasForwarded => forwardedMessages.isNotEmpty;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await SocketService.connectIfNotConnected();
    await _loadHistory();
    await _loadCurrentUser();
    await _loadPartnerUser();
    _initializeSocket();

    final forwarded = forwardMessages;
    if (forwarded != null && forwarded.isNotEmpty) {
      _messages.addAll(forwarded);
      _notify();
    }
  }

  void _initializeSocket() {
    SocketService.onMessageAdded(_onMessageAdded);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
    SocketService.onUserTyping(_onUserTyping);
    SocketService.addOnConnectionRestored(_onConnectionRestored);
  }

  void _onConnectionRestored() {
    unawaited(_fetchMissedMessages());
  }

  Future<void> _fetchMissedMessages() async {
    final id = _chatId;
    if (id == null || _refreshing || _disposed) return;

    _refreshing = true;
    try {
      final page = await ChatRepository.fetchAndCache(id, offset: 0, limit: 50);
      if (_disposed) return;
      await _decryptMessages(page.messages);

      final missed = mergeMissedMessages(_messages, page.messages);
      if (missed.isEmpty) return;

      _messages.addAll(missed);
      _messages.sort((a, b) => a.timeCreate.compareTo(b.timeCreate));
      _notify();
      if (_atBottom) onScrollToBottom?.call();
    } catch (e) {
      log.w(
        'ChatController: не удалось догрузить сообщения после реконнекта: $e',
      );
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statusTimer?.cancel();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    SocketService.removeOnConnectionRestored(_onConnectionRestored);
    SocketService.offMessageAdded(_onMessageAdded);
    SocketService.offMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    SocketService.offUserTyping(_onUserTyping);
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthService.getUserId();
    if (id == null || _disposed) return;
    _myId = id;
    try {
      final userData = await UserService.getUserById(id);
      ChatRepository.cacheProfile({...userData, 'id': id}).ignore();
      if (_disposed) return;
      _applyCurrentUser(
        userData['name'] ?? userData['login'],
        userData['avatar_url'] as String?,
      );
    } catch (e) {
      log.e(e);
      Map<String, dynamic>? cached;
      try {
        cached = await ChatRepository.cachedProfile(id);
      } catch (_) {}
      if (_disposed || cached == null) return;
      _applyCurrentUser(
        cached['name'] ?? cached['login'],
        cached['avatar_url'] as String?,
      );
    }
  }

  void _applyCurrentUser(String? name, String? avatarUrl) {
    _currentUser = Member(id: _myId!, name: name ?? 'Я', avatarUrl: avatarUrl);
    _notify();
  }

  Future<void> _loadPartnerUser() async {
    try {
      final userData = _userId != null
          ? await UserService.getUserById(_userId!)
          : await UserService.getUserByChat(_chatId!);

      if (userData['id'] != null) {
        ChatRepository.cacheProfile(userData).ignore();
      }
      _applyPartnerData(userData);
    } catch (e) {
      log.e(e);
      Map<String, dynamic>? cached;
      try {
        if (_userId != null) {
          cached = await ChatRepository.cachedProfile(_userId!);
        }
        if (cached == null && _chatId != null) {
          final chats = await ChatRepository.getChats(onCached: (_) {});
          final chat = chats.firstWhere(
            (c) => c.chatId == _chatId,
            orElse: () => chats.first,
          );
          if (chat.chatId == _chatId) {
            cached = {
              'id': chat.userId,
              'name': chat.userName,
              'avatar_url': chat.avatarUrl,
            };
          }
        }
      } catch (_) {}
      if (!_disposed && cached != null) _applyPartnerData(cached);
    }
  }

  void _applyPartnerData(Map<String, dynamic> userData) {
    if (_disposed) return;

    final partnerId = asInt(userData['id']);
    if (partnerId != null) _userId = partnerId;

    _partnerUser = Member(
      id: partnerId ?? -1,
      name: (userData['name'] ?? userData['login'] ?? 'Чат').toString(),
      avatarUrl: userData['avatar_url'] as String?,
      gender: userData['gender'] as String?,
    );

    if (userData['is_online'] == true) {
      _chatStatus = 'в сети';
    } else if (userData['last_seen'] != null) {
      final parsed = DateTime.tryParse(userData['last_seen'].toString());
      _lastSeenTime = parsed?.toLocal();
      _updateStatusText();
      _restartStatusTimer();
    } else {
      _chatStatus = 'был(а) давно';
    }

    _notify();
  }

  void _restartStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_disposed && _lastSeenTime != null && _chatStatus != 'печатает...') {
        _updateStatusText();
      }
    });
  }

  void _updateStatusText() {
    final prefix = _partnerUser?.gender == 'М'
        ? 'был'
        : (_partnerUser?.gender == 'Ж' ? 'была' : 'был(а)');

    final lastSeen = _lastSeenTime;
    if (lastSeen == null) {
      _chatStatus = '$prefix давно';
      return;
    }

    final now = DateTime.now();
    final timeStr = TimeFormatter.time(lastSeen);

    String relativeStr;
    if (TimeFormatter.isSameDay(lastSeen, now)) {
      final diff = now.difference(lastSeen);
      if (diff.inMinutes < 1) {
        relativeStr = 'только что';
      } else if (diff.inHours < 1) {
        relativeStr = '${diff.inMinutes} мин. назад';
      } else {
        relativeStr = 'сегодня в $timeStr';
      }
    } else if (TimeFormatter.isSameDay(
      lastSeen,
      now.subtract(const Duration(days: 1)),
    )) {
      relativeStr = 'вчера в $timeStr';
    } else {
      relativeStr =
          '${lastSeen.day} ${TimeFormatter.monthsGenitive[lastSeen.month]} в $timeStr';
    }

    _chatStatus = '$prefix $relativeStr';
    _notify();
  }

  Future<void> _loadHistory() async {
    final id = _chatId;
    if (id != null) {
      _isLoadingHistory = true;
      _notify();
      try {
        final history = await ChatRepository.getInitialMessages(
          id,
          onCached: (cached) async {
            if (_disposed) return;
            await _decryptMessages(cached);
            _replaceHistory(cached);
            _messageOffset = cached.length;
            _isLoadingHistory = false;
            _notify();
          },
          onUpdated: (fresh) async {
            if (_disposed) return;
            await _decryptMessages(fresh);
            _replaceHistory(fresh);
            _notify();
          },
        );
        if (_disposed) return;

        final messagesList = history.messages;
        if (messagesList.isNotEmpty) {
          await _decryptMessages(messagesList);
          _messages.insertAll(0, messagesList);
          _messageOffset = _messages.length;
        }
        _hasMoreMessages = history.hasMore;
        _notify();

        if (messagesList.isNotEmpty || !history.wasCachedShown) {
          SocketService.markAsRead(id);
        }
      } catch (e) {
        log.e(e);
        if (!_disposed && !ChatRepository.isOfflineError(e)) {
          onError?.call(
            'Не удалось загрузить переписку. Потяните вниз, чтобы обновить.',
            details: e,
          );
        }
      } finally {
        if (!_disposed) {
          _isLoadingHistory = false;
          _notify();
        }
      }

      try {
        SocketService.joinChat(id);
      } catch (e) {
        log.w('ChatController: нет соединения, история из кэша: $e');
      }
    }
  }

  Future<void> _decryptMessages(List<Message> msgs) async {
    final myPrivateKey = await KeyStorageService.getPrivateKey();
    for (var i = 0; i < msgs.length; i++) {
      final msg = msgs[i];
      if (!MessageCrypto.isContainer(msg.content)) continue;
      msgs[i] = msg.copyWith(
        content: MessageCrypto.display(msg.content, myPrivateKey),
      );
    }
  }

  void _replaceHistory(List<Message> history) {
    final merged = mergeHistoryPreservingLocal(history, _messages);
    _messages
      ..clear()
      ..addAll(merged);
  }

  Future<bool> loadMoreHistory() async {
    if (_isLoadingHistory || !_hasMoreMessages || _chatId == null) return false;

    _isLoadingHistory = true;
    _notify();

    try {
      final history = await ChatRepository.getOlderMessages(
        _chatId!,
        offset: _messageOffset,
        limit: _pageSize,
      );
      if (_disposed) return false;

      final newMessages = history.messages;
      _hasMoreMessages = history.hasMore;
      await _decryptMessages(newMessages);
      _messageOffset += newMessages.length;

      if (newMessages.isEmpty) return false;

      _messages.insertAll(0, newMessages);
      return true;
    } catch (e) {
      log.e('Ошибка подгрузки истории: $e');
      return false;
    } finally {
      if (!_disposed) {
        _isLoadingHistory = false;
        _notify();
      }
    }
  }

  void updateScrollState({required double pixels, required double maxExtent}) {
    final atBottom = pixels <= _bottomThreshold;
    if (atBottom != _atBottom || (atBottom && _newMessagesCount > 0)) {
      _atBottom = atBottom;
      if (atBottom) _newMessagesCount = 0;
      _notify();
    }
  }

  void markAtBottom() {
    _atBottom = true;
    _newMessagesCount = 0;
    _notify();
  }

  bool shouldPrefetchHistory(double pixels, double maxExtent) =>
      _hasMoreMessages &&
      !_isLoadingHistory &&
      pixels >= maxExtent - _historyPrefetchThreshold;

  List<Map<String, dynamic>> _asMaps(dynamic data) {
    if (data is Map) return [Map<String, dynamic>.from(data)];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Future<void> _onMessageAdded(dynamic data) async {
    final items = _asMaps(data);
    if (items.isEmpty) return;

    for (final result in items) {
      var incoming = Message.fromJson(result);

      final alreadyShown = _messages.any(
        (m) => m.timeCreate == incoming.timeCreate,
      );
      if (incoming.sender.id == _myId && alreadyShown) continue;

      if (MessageCrypto.isContainer(incoming.content)) {
        final myPrivateKey = await KeyStorageService.getPrivateKey();
        try {
          incoming = incoming.copyWith(
            content: MessageCrypto.decryptInbound(
              incoming.content,
              myPrivateKey ?? '',
            ),
          );
        } catch (_) {
          incoming = incoming.copyWith(content: MessageCrypto.placeholder);
        }
      }
      if (_disposed) return;

      if (!_messages.any((m) => m.timeCreate == incoming.timeCreate)) {
        _messages.add(incoming);
      }
      if (!_atBottom) _newMessagesCount++;
      _notify();

      if (_atBottom) onScrollToBottom?.call();
      final id = _chatId;
      if (id != null) {
        ChatRepository.cacheIncomingMessage(id, Message.fromJson(result));
      }
    }

    if (_chatId != null) SocketService.markAsRead(_chatId!);
  }

  Future<List<int>> searchCacheFallback(String query) async {
    final id = _chatId;
    if (id == null) return const [];
    try {
      final found = await ChatRepository.searchMessages(id, query: query);
      if (found.isEmpty || _disposed) return const [];

      final existingIds = _messages.map((m) => m.id).whereType<int>().toSet();
      final missing = found
          .where((m) => m.id != null && !existingIds.contains(m.id))
          .toList();

      if (missing.isNotEmpty) {
        for (final m in missing) {
          final at = _messages.indexWhere((e) => e.timeCreate > m.timeCreate);
          if (at == -1) {
            _messages.add(m);
          } else {
            _messages.insert(at, m);
          }
        }
        _notify();
      }

      final foundIds = found.map((m) => m.id).whereType<int>().toSet();
      final indices = <int>[];
      for (var i = 0; i < _messages.length; i++) {
        final mid = _messages[i].id;
        if (mid != null && foundIds.contains(mid)) indices.add(i);
      }
      return indices;
    } catch (e) {
      log.w('ChatController: поиск по кэшу не удался: $e');
      return const [];
    }
  }

  void _onMessageEdited(dynamic data) {
    for (final result in _asMaps(data)) {
      if (asInt(result['chat_id']) != _chatId) continue;

      final messageId = asInt(result['id']);
      if (messageId == null) continue;

      ChatRepository.cacheIncomingMessage(
        _chatId!,
        Message.fromJson({
          ...result,
          'sender': result['sender'] ?? {'id': -1, 'name': 'UNKNOWN'},
        }),
      ).ignore();

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index == -1) continue;
      _messages[index] = _messages[index].copyWith(
        content: (result['content'] ?? '').toString(),
        isEdited: true,
      );
      _notify();
    }
  }

  void _onMessageDeleted(dynamic data) {
    for (final result in _asMaps(data)) {
      if (asInt(result['sender_id']) == _myId) continue;
      if (asInt(result['chat_id']) != _chatId) continue;

      final deletedFor = asInt(result['deleted_for_user_id']);
      if (deletedFor != null && deletedFor != _myId) continue;

      final messageId = asInt(result['message_id']);
      if (messageId == null) continue;

      ChatRepository.removeCachedMessage(_chatId!, messageId).ignore();
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index == -1) continue;
      _messages.removeAt(index);
      _notify();
    }
  }

  void _onMessageStatusUpdated(dynamic data) {
    for (final result in _asMaps(data)) {
      if (asInt(result['chat_id']) != _chatId) continue;

      final readUpTo = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        if (message.sender.id == _myId &&
            message.status != MessageStatus.read &&
            message.timeCreate <= readUpTo) {
          _messages[i] = message.copyWith(status: MessageStatus.read);
        }
      }
      _notify();
    }
  }

  void _onUserStatusChanged(dynamic data) {
    for (final result in _asMaps(data)) {
      if (asInt(result['userId']) == _myId) continue;

      if (result['status'] == 'online') {
        _typingTimer?.cancel();
        _statusTimer?.cancel();
        _chatStatus = 'в сети';
        _lastSeenTime = null;
        _notify();
        continue;
      }

      _typingTimer?.cancel();
      final lastSeenStr = result['last_seen'];
      final parsed = lastSeenStr is String
          ? DateTime.tryParse(lastSeenStr)?.toLocal()
          : null;

      if (parsed != null) {
        _lastSeenTime = parsed;
        if (_chatStatus != 'печатает...') _updateStatusText();
        _restartStatusTimer();
      } else if (_chatStatus != 'печатает...') {
        _chatStatus = 'был(а) давно';
        _notify();
      }
    }
  }

  void _onUserTyping(dynamic data) {
    for (final result in _asMaps(data)) {
      if (asInt(result['chat_id']) != _chatId) continue;
      if (asInt(result['user_id']) == _myId) continue;

      if (result['is_typing'] == true) {
        _chatStatus = 'печатает...';
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_disposed) return;
          if (_chatStatus == 'печатает...') {
            _chatStatus = 'в сети';
            _notify();
          }
        });
      } else {
        _typingTimer?.cancel();
        _chatStatus = 'в сети';
      }
      _notify();
    }
  }

  void scheduleTypingStatus(bool isTyping) {
    final id = _chatId;
    if (id == null) return;
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      SocketService.sendTypingStatus(id, isTyping);
    });
  }

  Future<void> sendMessage(String text) async {
    final timeCreate = DateTime.now().millisecondsSinceEpoch;

    if (hasForwarded) {
      await _sendForwarded();
      return;
    }

    if (text.trim().isEmpty) return;

    final EncryptResult wire;
    try {
      wire = await MessageCrypto.encryptWithStatus(text, _userId);
    } on EncryptionUnavailableException catch (e) {
      if (!_disposed) onError?.call(e.message);
      return;
    }

    if (_editingMessageId != null) {
      final editResult = await SocketService.editMessage(
        _editingMessageId!,
        wire.content,
      );
      if (!editResult.ok) {
        if (!_disposed) {
          onError?.call(
            'Не удалось отредактировать сообщение: ${editResult.error}',
          );
        }
        return;
      }
      _editingMessageId = null;
      _replyingTo = null;
      _notify();
      onInputCleared?.call();
      return;
    }

    if (_chatId == null && !await _ensureChat()) return;

    final sender = _currentUser;
    if (sender == null) return;

    final replyPayload = Message.buildReplyPayload(_replyingTo);
    final tempMessage = Message(
      sender: sender,
      content: text,
      timeCreate: timeCreate,
      status: MessageStatus.sending,
      reply: replyPayload,
    );

    _messages.add(tempMessage);
    _replyingTo = null;
    _atBottom = true;
    _newMessagesCount = 0;
    _notify();

    onInputCleared?.call();
    HapticFeedback.lightImpact();
    onScrollToBottom?.call();

    final result = await SocketService.sendOrQueue(
      OutboxMessage(
        content: wire.content,
        isEncrypted: wire.encrypted,
        chatId: _chatId!,
        reply: replyPayload,
        timeCreate: timeCreate,
      ),
    );

    if (result.ok) {
      _replaceMessage(
        tempMessage,
        tempMessage.copyWith(
          id: asInt(result.data is Map ? result.data['message_id'] : null),
          status: MessageStatus.sent,
        ),
      );
    } else if (result.error == 'OFFLINE') {
      return;
    } else {
      if (!_disposed) {
        onError?.call('Не удалось отправить сообщение: ${result.error}');
      }
      _replaceMessage(
        tempMessage,
        tempMessage.copyWith(status: MessageStatus.error),
      );
    }
  }

  Future<void> _sendForwarded() async {
    final originals = forwardedMessages;
    if (originals.isEmpty) return;

    final localMessages = [
      for (final msg in originals)
        msg.copyWith(status: MessageStatus.sending, reply: null),
    ];
    for (var i = 0; i < originals.length; i++) {
      _replaceMessage(originals[i], localMessages[i]);
    }

    for (final msg in localMessages) {
      final EncryptResult wire;
      try {
        wire = await MessageCrypto.encryptWithStatus(msg.content, _userId);
      } on EncryptionUnavailableException catch (e) {
        _replaceMessage(msg, msg.copyWith(status: MessageStatus.error));
        if (!_disposed) onError?.call(e.message);
        continue;
      }

      final result = await SocketService.sendOrQueue(
        OutboxMessage(
          content: wire.content,
          isEncrypted: wire.encrypted,
          chatId: _chatId!,
          forward: msg.forward,
          timeCreate: msg.timeCreate,
          imageUrl: msg.imageUrl,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          fileSize: msg.fileSize,
          voiceUrl: msg.voiceUrl,
          voiceDuration: msg.voiceDurationSeconds,
        ),
      );

      if (result.ok) {
        _replaceMessage(
          msg,
          msg.copyWith(
            id: asInt(result.data is Map ? result.data['message_id'] : null),
            status: MessageStatus.sent,
          ),
        );
      } else if (result.error == 'OFFLINE') {
        continue;
      } else {
        if (!_disposed) {
          onError?.call('Не удалось отправить сообщение: ${result.error}');
        }
        _replaceMessage(msg, msg.copyWith(status: MessageStatus.error));
      }
    }
  }

  void _replaceMessage(Message old, Message updated) {
    final index = _messages.indexWhere(
      (m) => m.timeCreate == updated.timeCreate,
    );
    if (index != -1) {
      _messages[index] = updated;
      _notify();
    }

    final id = _chatId;
    if (id == null) return;
    if (updated.id != null && old.id == null) {
      ChatRepository.replaceTempWithServer(id, old, updated).ignore();
    } else if (updated.id != null) {
      ChatRepository.cacheIncomingMessage(id, updated).ignore();
    }
  }

  Future<bool> _ensureChat() async {
    if (_chatId != null) return true;
    final partnerId = _userId;
    if (partnerId == null) return false;

    try {
      _chatId = await ChatService.createChatWith(partnerId);
      await SocketService.connectIfNotConnected();
      SocketService.joinChat(_chatId!);
      _notify();
      return true;
    } catch (e) {
      if (!_disposed) {
        onError?.call(
          'Не удалось начать диалог. Проверьте соединение и попробуйте ещё раз.',
          details: e,
        );
      }
      return false;
    }
  }

  Future<void> pickAndSendImage() async {
    final sender = _currentUser;
    if (sender == null) return;

    final picked = await _mediaHandler.pickImage(sender: sender);
    if (picked == null || _disposed) return;
    if (!await _ensureChat()) return;

    final tempMsg = picked.tempMessage;
    _messages.add(tempMsg);
    _notify();

    try {
      final uploaded = await ChatService.sendImage(
        _chatId!,
        picked.file,
        tempMsg,
      );
      if (_disposed) return;
      _replaceMessage(
        tempMsg,
        tempMsg.copyWith(
          id: uploaded.id,
          imageUrl: uploaded.imageUrl,
          isTemp: false,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      onError?.call('Ошибка отправки фото: $e');
    }
  }

  Future<void> pickAndSendFile() async {
    final sender = _currentUser;
    if (sender == null) return;

    final picked = await _mediaHandler.pickFile(sender: sender);
    if (picked == null || _disposed) return;
    if (!await _ensureChat()) return;

    final tempMsg = picked.tempMessage;
    final fileName = tempMsg.fileName ?? '';
    _messages.add(tempMsg);
    _notify();

    try {
      final uploaded = await ChatService.sendFile(
        _chatId!,
        picked.file,
        tempMsg,
        displayName: fileName,
      );
      if (_disposed) return;
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
      if (_disposed) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      onError?.call('Ошибка отправки файла: $e');
    }
  }

  Future<void> sendVoiceMessage(File file, int durationSeconds) async {
    final sender = _currentUser;
    if (sender == null) return;
    if (!await _ensureChat()) return;

    final tempMsg = Message(
      sender: sender,
      voiceUrl: 'temp:${file.path}',
      voiceDurationSeconds: durationSeconds,
      timeCreate: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.sending,
      isTemp: true,
    );

    _messages.add(tempMsg);
    _notify();

    try {
      final uploaded = await ChatService.sendVoice(
        _chatId!,
        file,
        durationSeconds,
        tempMsg,
      );
      if (_disposed) return;
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
    } catch (e) {
      if (_disposed) return;
      _replaceMessage(tempMsg, tempMsg.copyWith(status: MessageStatus.error));
      onError?.call('Ошибка отправки голосового: $e');
    }
  }

  void toggleSelection(Message message) {
    _messageActions.toggleSelection(message, _notify);
  }

  void clearSelection() {
    _messageActions.clearSelection(_messages, _notify);
  }

  Message? buildReply(Message message) {
    final replyTo = _messageActions.startReply(message);
    if (replyTo == null) return null;
    _replyingTo = replyTo;
    _editingMessageId = null;
    _notify();
    return replyTo;
  }

  void cancelReply() {
    _replyingTo = null;
    _notify();
  }

  String? changeEditing(Message message) {
    if (message.id == null) return null;

    if (_editingMessageId == message.id) {
      _editingMessageId = null;
      _notify();
      return '';
    }

    _editingMessageId = message.id;
    _replyingTo = null;
    _notify();
    return message.content;
  }

  void deleteMessage(Message message, {required bool isLocal}) {
    _messages.removeWhere((m) => m.id == message.id);
    if (_editingMessageId == message.id) {
      _editingMessageId = null;
      onInputCleared?.call();
    }
    _notify();

    final id = _chatId;
    if (id != null && message.id != null) {
      SocketService.deleteMessage(message.id!, id, isLocal);
    }
  }

  void removeSelectedMessages() {
    _messages.removeWhere((m) => m.isSelected && m.id != null);
    _notify();
  }

  List<Message> buildForwardCopies() {
    final sender = _currentUser;
    if (sender == null) return const [];
    return _messageActions.buildForwardCopies(
      selectedMessages: selectedMessages,
      sender: sender,
    );
  }

  void removeForwarded(Message message) {
    _messages.remove(message);
    _notify();
  }

  void cancelForwarded() {
    _messages.removeWhere((msg) => msg.status == MessageStatus.forwarding);
    _notify();
  }
}

List<Message> mergeHistoryPreservingLocal(
  List<Message> history,
  List<Message> current,
) {
  final forwarded = current.where((m) => m.status == MessageStatus.forwarding);
  return [...history, ...forwarded];
}

List<Message> mergeMissedMessages(List<Message> current, List<Message> fresh) {
  final known = current.map((m) => m.id).whereType<int>().toSet();
  return fresh
      .where((m) => m.id != null && !known.contains(m.id))
      .toList(growable: false);
}
