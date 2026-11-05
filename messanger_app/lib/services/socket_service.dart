import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'auth_service.dart';
import '../utils/json_utils.dart';
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
  final bool isEncrypted;
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
    this.isEncrypted = false,
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

  Map<String, dynamic> toJson() => {
    'content': content,
    'is_encrypted': isEncrypted,
    'chat_id': chatId,
    'reply': reply,
    'forward': forward,
    'time_create': timeCreate,
    'image_url': imageUrl,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_size': fileSize,
    'voice_url': voiceUrl,
    'voice_duration': voiceDuration,
  };

  static OutboxMessage? fromJson(Map<String, dynamic> json) {
    final chatId = asInt(json['chat_id']);
    final timeCreate = asInt(json['time_create']);
    if (chatId == null || timeCreate == null) return null;
    return OutboxMessage(
      content: (json['content'] ?? '').toString(),
      isEncrypted: json['is_encrypted'] == true,
      chatId: chatId,
      reply: json['reply'],
      forward: json['forward'],
      timeCreate: timeCreate,
      imageUrl: json['image_url'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: asInt(json['file_size']),
      voiceUrl: json['voice_url'] as String?,
      voiceDuration: asInt(json['voice_duration']),
    );
  }
}

abstract class OutboxStorage {
  Future<List<OutboxMessage>> load();
  Future<void> save(OutboxMessage message);
  Future<void> remove(int timeCreate);
  Future<void> clear();
}

class SocketService {
  static io.Socket? _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static final Map<String, Set<Function(dynamic)>> _handlers = {};
  static final Map<String, Function(dynamic)> _nativeListeners = {};

  static Function()? onConnectionLost;
  static final Set<void Function()> _onConnectionRestoredHandlers = {};

  static void addOnConnectionRestored(void Function() handler) =>
      _onConnectionRestoredHandlers.add(handler);

  static void removeOnConnectionRestored(void Function() handler) =>
      _onConnectionRestoredHandlers.remove(handler);

  static void _notifyConnectionRestored() {
    for (final h in _onConnectionRestoredHandlers.toList()) {
      h();
    }
  }

  static final List<OutboxMessage> _outbox = [];
  static bool _flushing = false;

  static OutboxStorage? outboxStorage;

  static List<OutboxMessage> get outboxSnapshot => List.unmodifiable(_outbox);

  static Function()? onOutboxChanged;

  static void _enqueue(OutboxMessage message) {
    _outbox.add(message);
    onOutboxChanged?.call();
    outboxStorage
        ?.save(message)
        .catchError((Object e) => log.w('Outbox: не удалось сохранить: $e'));
  }

  static void _dequeue(OutboxMessage message) {
    if (!_outbox.remove(message)) return;
    onOutboxChanged?.call();
    outboxStorage
        ?.remove(message.timeCreate)
        .catchError((Object e) => log.w('Outbox: не удалось удалить: $e'));
  }

  static void restoreOutbox(List<OutboxMessage> messages) {
    if (messages.isEmpty) return;
    final known = _outbox.map((m) => m.timeCreate).toSet();
    for (final message in messages) {
      if (known.add(message.timeCreate)) _outbox.add(message);
    }
    onOutboxChanged?.call();
    unawaited(_flushOutbox());
  }

  static void clearOutbox() {
    _outbox.clear();
    onOutboxChanged?.call();
    outboxStorage?.clear().catchError(
      (Object e) => log.w('Outbox: не удалось очистить: $e'),
    );
  }

  static Future<SocketAckResult> sendOrQueue(OutboxMessage message) async {
    if (!isConnected) {
      _enqueue(message);
      return const SocketAckResult(false, 'OFFLINE', null);
    }
    final result = await emitWithAck(
      'send_message',
      _payloadOf(message),
      const Duration(seconds: 12),
    );

    if (!result.ok && (result.error == 'TIMEOUT' || !isConnected)) {
      _enqueue(message);
      return const SocketAckResult(true, null, {'queued': true});
    }
    return result;
  }

  static Map<String, dynamic> _payloadOf(OutboxMessage m) => {
    'content': m.content,
    'is_encrypted': m.isEncrypted,
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
          _dequeue(message);
        } else if (result.error != 'TIMEOUT') {
          _dequeue(message);
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
      _dequeue(message);
    }
    return result;
  }

  static void removeFromOutbox(OutboxMessage message) => _dequeue(message);

  static Future<SocketAckResult> _emitSend(OutboxMessage m) => sendMessage(
    m.content,
    m.chatId,
    m.reply,
    m.forward,
    m.timeCreate,
    isEncrypted: m.isEncrypted,
    imageUrl: m.imageUrl,
    fileUrl: m.fileUrl,
    fileName: m.fileName,
    fileSize: m.fileSize,
    voiceUrl: m.voiceUrl,
    voiceDuration: m.voiceDuration,
  );

  static void _addHandler(String event, Function(dynamic) callback) {
    (_handlers[event] ??= <Function(dynamic)>{}).add(callback);
    _attach(event);
  }

  static void _removeHandler(String event, Function(dynamic)? callback) {
    final set = _handlers[event];
    if (set == null) return;

    if (callback == null) {
      set.clear();
    } else {
      set.remove(callback);
    }

    if (set.isEmpty) {
      _detach(event);
      _handlers.remove(event);
    }
  }

  static void _attach(String event) {
    final socket = _socket;
    final handlers = _handlers[event];
    if (socket == null || handlers == null || handlers.isEmpty) return;
    if (_nativeListeners.containsKey(event)) return;

    void dispatcher(dynamic data) {
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

  static void _detach(String event) {
    final dispatcher = _nativeListeners.remove(event);
    if (dispatcher != null) _socket?.off(event, dispatcher);
  }

  static void _rebindAllHandlers() {
    for (final event in _handlers.keys.toList()) {
      _detach(event);
      _attach(event);
    }
  }

  static Future<void> connectIfNotConnected() async {
    if (_socket != null && _socket!.connected) return;
    if (_socket != null) return;

    final token = await AuthService.getToken();
    final baseUrl = dotenv.env['BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('BASE_URL не настроен');
    }

    _socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'timeout': 10000,
    });

    _nativeListeners.clear();

    _socket!.onConnect((_) {
      log.i('Socket connected');
      _rebindAllHandlers();
      _notifyConnectionRestored();
      _flushOutbox();
    });
    _socket!.onDisconnect((_) {
      log.i('Socket disconnected');
      onConnectionLost?.call();
    });
    _socket!.onConnectError((e) => log.w('Socket connect error: $e'));
    _socket!.onError((e) => log.e('Socket error: $e'));
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
    bool isEncrypted = false,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? voiceUrl,
    int? voiceDuration,
  }) async {
    return emitWithAck('send_message', {
      'content': content,
      'is_encrypted': isEncrypted,
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
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
