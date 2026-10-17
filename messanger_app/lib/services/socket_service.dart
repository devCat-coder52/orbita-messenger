import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'auth_service.dart';
import '../utils/logger.dart';

class SocketAckResult {
  final bool ok;
  final String? error;
  final dynamic data;

  const SocketAckResult(this.ok, this.error, this.data);

  factory SocketAckResult.fromAck(dynamic ack) {
    if (ack is Map && ack.containsKey('status')) {
      return SocketAckResult(
        ack['status'] == 'ok',
        ack['error']?.toString(),
        ack,
      );
    }
    return SocketAckResult(true, null, ack);
  }

  static SocketAckResult get timeout =>
      const SocketAckResult(false, 'TIMEOUT', null);

  static SocketAckResult failed(Object e) =>
      SocketAckResult(false, e.toString(), null);
}

class OutboxMessage {
  final String content;
  final int chatId;
  final Object? reply;
  final Object? forward;
  final int timeCreate;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? voiceUrl;
  final int? voiceDuration;

  const OutboxMessage({
    required this.content,
    required this.chatId,
    this.reply,
    this.forward,
    required this.timeCreate,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.voiceUrl,
    this.voiceDuration,
  });
}

class SocketService {
  static io.Socket? _socket;
  static bool get isConnected => _socket?.connected ?? false;
  static bool _connecting = false;

  static final Map<String, Set<Function(dynamic)>> _handlers = {};
  static final Map<String, Function(dynamic)> _nativeListeners = {};

  static Function()? onConnectionLost;
  static Function()? onConnectionRestored;

  static final List<OutboxMessage> _outbox = [];
  static bool _flushing = false;

  static List<OutboxMessage> get outboxSnapshot => List.unmodifiable(_outbox);

  static Function()? onOutboxChanged;

  static Future<void> connectIfNotConnected() async {
    if (_socket != null && _socket!.connected) return;
    if (_connecting) return;

    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    final token = await AuthService.getToken();
    final baseUrl = dotenv.env['BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('BASE_URL не настроен');
    }

    _connecting = true;

    try {
      final socket = io.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        'auth': {'token': token},
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 10000,
        'timeout': 10000,
      });
      _socket = socket;

      socket.onConnect((_) {
        log.i('Socket connected');
        _rebindAllHandlers();
        onConnectionRestored?.call();
        _flushOutbox();
      });
      socket.onDisconnect((_) {
        log.i('Socket disconnected');
        onConnectionLost?.call();
      });
      socket.onConnectError((e) => log.w('Socket connect error: $e'));
      socket.onError((e) => log.e('Socket error: $e'));

      if (!socket.connected) {
        socket.connect();
        await _waitForConnected(const Duration(seconds: 10));
      }
    } finally {
      _connecting = false;
    }
  }

  static Future<void> _waitForConnected(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_socket?.connected ?? false) return;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    log.w('Socket connection timed out after ${timeout.inSeconds}s');
  }

  static Future<SocketAckResult> sendOrQueue(OutboxMessage message) async {
    if (!isConnected) {
      _queueForDelivery(message);
      return const SocketAckResult(false, 'OFFLINE', null);
    }
    final result = await emitWithAck(
      'send_message',
      _payloadOf(message),
      const Duration(seconds: 12),
    );

    if (!result.ok && (result.error == 'TIMEOUT' || !isConnected)) {
      _queueForDelivery(message);
      return const SocketAckResult(true, null, {'queued': true});
    }
    return result;
  }

  static void _queueForDelivery(OutboxMessage message) {
    if (_outbox.contains(message)) return;
    _outbox.add(message);
    onOutboxChanged?.call();
  }

  static Map<String, dynamic> _payloadOf(OutboxMessage m) => {
    'content': m.content,
    'chat_id': m.chatId,
    'reply': m.reply,
    'forward': m.forward,
    'time_create': m.timeCreate,
    'image_url': m.imageUrl,
    'file_url': m.fileUrl,
    'file_name': m.fileName,
    'file_size': m.fileSize,
    'voice_url': m.voiceUrl,
    'voice_duration': m.voiceDuration,
  };

  static Future<void> _flushOutbox() async {
    if (_flushing || _outbox.isEmpty || !isConnected) return;
    _flushing = true;
    try {
      for (final message in _outbox.toList()) {
        final result = await _emitSend(message);
        if (result.ok) {
          _outbox.remove(message);
          onOutboxChanged?.call();
        } else if (result.error != 'TIMEOUT') {
          _outbox.remove(message);
          onOutboxChanged?.call();
        } else {
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static Future<SocketAckResult> retryOutbox(OutboxMessage message) async {
    final result = await _emitSend(message);
    if (result.ok) {
      _outbox.remove(message);
      onOutboxChanged?.call();
    }
    return result;
  }

  static void removeFromOutbox(OutboxMessage message) {
    if (_outbox.remove(message)) onOutboxChanged?.call();
  }

  static Future<SocketAckResult> _emitSend(OutboxMessage m) => sendMessage(
    m.content,
    m.chatId,
    m.reply,
    m.forward,
    m.timeCreate,
    imageUrl: m.imageUrl,
    fileUrl: m.fileUrl,
    fileName: m.fileName,
    fileSize: m.fileSize,
    voiceUrl: m.voiceUrl,
    voiceDuration: m.voiceDuration,
  );

  static void _addHandler(String event, Function(dynamic) callback) {
    (_handlers[event] ??= <Function(dynamic)>{}).add(callback);
    final dispatcher = _nativeListeners.putIfAbsent(
      event,
      () => _makeDispatcher(event),
    );
    _socket?.on(event, dispatcher);
  }

  static Function(dynamic) _makeDispatcher(String event) {
    void dispatcher(dynamic data) {
      final normalized = _normalizeEventData(data);
      for (final cb in _handlers[event]?.toList() ?? []) {
        try {
          cb(normalized);
        } catch (e) {
          log.e('Socket handler error [$event]: $e');
        }
      }
    }

    return dispatcher;
  }

  static List<dynamic> _normalizeEventData(dynamic data) {
    if (data == null) return const [];
    if (data is List) {
      return data.expand((e) => e is List ? e : [e]).toList();
    }
    return [data];
  }

  static void _removeHandler(String event, Function(dynamic)? callback) {
    final set = _handlers[event];
    if (set == null) return;
    if (callback != null) {
      set.remove(callback);
    } else {
      set.clear();
    }
  }

  static void _ensureDispatcher(String event) {
    final socket = _socket;
    if (socket == null) return;

    if (_nativeListeners.containsKey(event)) return;

    void dispatcher(dynamic data) {
      final handlers = _handlers[event];
      if (handlers == null || handlers.isEmpty) return;
      for (final cb in handlers.toList()) {
        try {
          cb(data);
        } catch (e) {
          log.e('Socket handler error [$event]: $e');
        }
      }
    }

    _nativeListeners[event] = dispatcher;
    socket.on(event, dispatcher);
  }

  static void _rebindAllHandlers() {
    _nativeListeners.clear();
    for (final event in _handlers.keys.toList()) {
      _ensureDispatcher(event);
    }
  }

  static void emit(String event, [dynamic data]) => _socket?.emit(event, data);
  static void on(String event, Function(dynamic) callback) =>
      _addHandler(event, callback);
  static void off(String event, [Function(dynamic)? callback]) =>
      _removeHandler(event, callback);

  static Future<SocketAckResult> emitWithAck(
    String event, [
    dynamic data,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw Exception('Нет соединения с сервером');
    }

    final completer = Completer<dynamic>();
    var answered = false;
    void handleAck(dynamic response) {
      if (answered) return;
      answered = true;
      completer.complete(response);
    }

    try {
      socket.emitWithAck(event, data, ack: handleAck);
    } catch (e) {
      return SocketAckResult.failed(e);
    }

    try {
      final ack = await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(event),
      );
      return SocketAckResult.fromAck(ack);
    } on TimeoutException {
      return SocketAckResult.timeout;
    } catch (e) {
      return SocketAckResult.failed(e);
    }
  }

  static void clearSessionState() {
    disconnect();

    _flushing = false;
    if (_outbox.isNotEmpty) {
      _outbox.clear();
      onOutboxChanged?.call();
    }

    _handlers.clear();
    _nativeListeners.clear();

    onConnectionLost = null;
    onConnectionRestored = null;
    onOutboxChanged = null;
  }

  static void joinChat(int chatId) => emit('join_chat', chatId);
  static void leaveChat(int chatId) => emit('leave_chat', chatId);

  static Future<SocketAckResult> markAsRead(int chatId) =>
      emitWithAck('mark_as_read', {'chat_id': chatId});

  static void sendTypingStatus(int chatId, bool isTyping) =>
      emit('typing', {'chat_id': chatId, 'is_typing': isTyping});

  static Future<SocketAckResult> sendMessage(
    String content,
    int chatId,
    Object? replyTo,
    Object? forward,
    int timeCreate, {
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? voiceUrl,
    int? voiceDuration,
  }) async {
    return emitWithAck('send_message', {
      'content': content,
      'chat_id': chatId,
      'reply': replyTo,
      'forward': forward,
      'time_create': timeCreate,
      'image_url': imageUrl,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'voice_url': voiceUrl,
      'voice_duration': voiceDuration,
    });
  }

  static Future<SocketAckResult> editMessage(int messageId, String content) =>
      emitWithAck('edit_message', {
        'message_id': messageId,
        'content': content,
      });

  static Future<SocketAckResult> deleteMessage(
    int messageId,
    int chatId,
    bool isLocal,
  ) => emitWithAck('delete_message', {
    'message_id': messageId,
    'chat_id': chatId,
    'is_local': isLocal,
  });

  static void onMessageAdded(Function(dynamic) callback) =>
      _addHandler('message_added', callback);
  static void offMessageAdded([Function(dynamic)? callback]) =>
      _removeHandler('message_added', callback);

  static void onMessageEdited(Function(dynamic) callback) =>
      _addHandler('message_edited', callback);
  static void offMessageEdited([Function(dynamic)? callback]) =>
      _removeHandler('message_edited', callback);

  static void onMessageDeleted(Function(dynamic) callback) =>
      _addHandler('message_deleted', callback);
  static void offMessageDeleted([Function(dynamic)? callback]) =>
      _removeHandler('message_deleted', callback);

  static void onMessageStatusUpdated(Function(dynamic) callback) =>
      _addHandler('message_status_updated', callback);
  static void offMessageStatusUpdated([Function(dynamic)? callback]) =>
      _removeHandler('message_status_updated', callback);

  static void onUserStatusChanged(Function(dynamic) callback) =>
      _addHandler('user_status_changed', callback);
  static void offUserStatusChanged([Function(dynamic)? callback]) =>
      _removeHandler('user_status_changed', callback);

  static void onUserTyping(Function(dynamic) callback) =>
      _addHandler('user_typing', callback);
  static void offUserTyping([Function(dynamic)? callback]) =>
      _removeHandler('user_typing', callback);

  static void disconnect() {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
  }
}
