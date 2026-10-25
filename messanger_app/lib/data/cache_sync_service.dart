import 'dart:async';

import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../utils/logger.dart';
import 'cache_database.dart';
import 'chat_repository.dart';

class CacheSyncService {
  const CacheSyncService._();

  static bool _started = false;
  static int? _myId;

  static void start() {
    if (_started) return;
    _started = true;
    SocketService.addOnConnectionRestored(_onConnectionRestored);
    unawaited(_init());
  }

  static void stop() {
    if (!_started) return;
    _started = false;
    _myId = null;
    SocketService.removeOnConnectionRestored(_onConnectionRestored);
    SocketService.offMessageAdded(_onMessageAdded);
    SocketService.offMessageEdited(_onMessageEdited);
    SocketService.offMessageDeleted(_onMessageDeleted);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    unawaited(CacheDatabase.clearAll());
  }

  static Future<void> _init() async {
    try {
      _myId = await AuthService.getUserId();
    } catch (_) {
      _myId = null;
    }

    SocketService.onMessageAdded(_onMessageAdded);
    SocketService.onMessageEdited(_onMessageEdited);
    SocketService.onMessageDeleted(_onMessageDeleted);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
  }

  static int? _asInt(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static List<Map<String, dynamic>> _items(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return const [];
  }

  static void _onConnectionRestored() {
    unawaited(reloadChats());
  }

  static void _onMessageAdded(dynamic data) {
    for (final json in _items(data)) {
      final chatId = _asInt(json['chat_id']);
      final messageId = _asInt(json['id']);
      if (chatId == null || messageId == null) continue;
      ChatRepository.cacheIncomingMessage(
        chatId,
        Message.fromJson(json),
      ).catchError((Object e) => log.w('CacheSync add: $e'));
      unawaited(_patchChatPreview(chatId, json));
    }
  }

  static Future<void> _patchChatPreview(
    int chatId,
    Map<String, dynamic> m,
  ) async {
    final type = switch (m) {
      _ when m['image_url'] != null => 'image',
      _ when m['voice_url'] != null => 'voice',
      _ when m['file_url'] != null => 'file',
      _ => 'text',
    };
    final senderId = m['sender'] is Map
        ? _asInt((m['sender'] as Map)['id'])
        : _asInt(m['sender_id']);
    await CacheDatabase.patchChatPreview(chatId, {
      'message_sender': senderId,
      'message_forwarder': _asInt(m['source_user_id']),
      'message_time': _asInt(m['time_create']),
      'message_text': m['content'],
      'message_type': type,
    });
  }

  static void _onMessageEdited(dynamic data) {
    for (final json in _items(data)) {
      final messageId = _asInt(json['id']);
      if (messageId == null) continue;
      unawaited(_applyEdit(messageId, json));
    }
  }

  static Future<void> _applyEdit(
    int messageId,
    Map<String, dynamic> json,
  ) async {
    final chats = await CacheDatabase.loadChatsJson();
    for (final c in chats) {
      final chatId = _asInt(c['chat_id']);
      if (chatId == null) continue;
      final stored = await CacheDatabase.findMessage(chatId, messageId);
      if (stored == null) continue;
      final updated = <String, dynamic>{
        ...stored,
        if (json.containsKey('content')) 'content': json['content'],
        'is_edited': true,
      };
      await CacheDatabase.cacheMessagesRaw(chatId, [updated]);
      if (json.containsKey('content')) {
        await CacheDatabase.patchChatPreview(chatId, {
          'message_text': json['content'],
        });
      }
    }
  }

  static void _onMessageDeleted(dynamic data) {
    for (final item in _items(data)) {
      final chatId = _asInt(item['chat_id']);
      final messageId = _asInt(item['message_id']);
      if (chatId == null || messageId == null) continue;
      ChatRepository.removeCachedMessage(
        chatId,
        messageId,
      ).catchError((Object e) => log.w('CacheSync delete: $e'));
    }
  }

  static void _onMessageStatusUpdated(dynamic data) {
    for (final item in _items(data)) {
      final chatId = _asInt(item['chat_id']);
      if (chatId == null) continue;
      final updatedBy = _asInt(item['updated_by']);
      if (updatedBy != null && updatedBy == _myId) {
        ChatRepository.markOutgoingRead(chatId, updatedBy).ignore();
      } else {
        ChatRepository.markChatRead(chatId).ignore();
      }
    }
  }

  static Future<void> reloadChats() async {
    try {
      final fresh = await ChatService.fetchChats(null);
      await CacheDatabase.replaceAllChats(
        fresh.map((c) => c.toJson()).toList(),
      );
    } catch (e) {
      log.w('CacheSync: не удалось обновить список чатов: $e');
    }
  }
}
