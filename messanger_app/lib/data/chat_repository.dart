import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/key_storage_service.dart';
import '../services/message_crypto.dart';

import '../utils/logger.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/global_search_hit.dart';
import '../utils/json_utils.dart';

import 'cache_database.dart';

class ChatRepository {
  const ChatRepository._();

  static bool isOfflineError(Object e) => switch (e) {
    DioException(:final type) =>
      type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.connectionError,
    SocketException _ => true,
    _ => false,
  };

  static Future<List<Chat>> getChats({
    required void Function(List<Chat> cached) onCached,
  }) async {
    final cached = await _chatsFromCache();
    if (cached.isNotEmpty) {
      onCached(cached);
    }
    try {
      final fresh = await ChatService.fetchChats(null);
      final changed = !_sameChatSet(cached, fresh);
      if (changed) {
        await CacheDatabase.replaceAllChats(
          fresh.map((c) => c.toJson()).toList(),
        );
      }
      return fresh;
    } catch (e) {
      if (isOfflineError(e) && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  static bool _sameChatSet(List<Chat> cached, List<Chat> fresh) {
    if (cached.length != fresh.length) return false;
    for (var i = 0; i < fresh.length; i++) {
      final a = cached[i];
      final b = fresh[i];
      if (a.chatId != b.chatId ||
          a.userId != b.userId ||
          a.messageTime != b.messageTime ||
          a.messageText != b.messageText ||
          a.isOnline != b.isOnline ||
          a.unreadCount != b.unreadCount) {
        return false;
      }
    }
    return true;
  }

  /// Чат из локального кэша без обращения к сети.
  static Future<Chat?> cachedChat(int chatId) async {
    final chats = await _chatsFromCache();
    for (final chat in chats) {
      if (chat.chatId == chatId) return chat;
    }
    return null;
  }

  static Future<List<Chat>> _chatsFromCache() async {
    try {
      final rows = await CacheDatabase.loadChatsJson();
      return rows.map((j) => Chat.fromJson(j)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> cacheChat(Chat chat) async {
    if (chat.chatId == null) return;
    await CacheDatabase.upsertChat(chat.toJson());
  }

  static Future<void> removeCachedChat(int chatId) =>
      CacheDatabase.deleteChat(chatId);

  static Future<({List<Message> messages, bool hasMore, bool wasCachedShown})>
  getInitialMessages(
    int chatId, {
    int limit = 50,
    required void Function(List<Message> cached) onCached,
    required void Function(List<Message> fresh, bool hasMore) onUpdated,
  }) async {
    List<Message> cachedMessages = const [];
    bool cachedHasMore = true;
    try {
      final rows = await CacheDatabase.loadMessages(chatId, limit: limit);
      cachedMessages = rows
          .where(CacheDatabase.isCacheable)
          .map((j) => Message.fromJson(j))
          .toList();
      final total = await CacheDatabase.countMessages(chatId);
      cachedHasMore = total > limit;
    } catch (_) {}

    if (cachedMessages.isNotEmpty) {
      onCached(cachedMessages);
      unawaited(
        fetchAndCache(chatId, offset: 0, limit: limit)
            .then((server) {
              if (server.messages.isEmpty) return;
              onUpdated(server.messages, server.hasMore);
            })
            .catchError((Object e) {
              log.w(
                'ChatRepository: фоновое обновление истории не удалось: $e',
              );
            }),
      );
      return (
        messages: const <Message>[],
        hasMore: cachedHasMore,
        wasCachedShown: true,
      );
    }

    try {
      final server = await fetchAndCache(chatId, offset: 0, limit: limit);
      return (
        messages: server.messages,
        hasMore: server.hasMore,
        wasCachedShown: false,
      );
    } catch (e) {
      if (isOfflineError(e)) {
        final pending = await _pendingFromCache(chatId);
        return (messages: pending, hasMore: false, wasCachedShown: false);
      }
      rethrow;
    }
  }

  static Future<List<Message>> _pendingFromCache(int chatId) async {
    try {
      final rows = await CacheDatabase.loadMessages(chatId, limit: 100);
      return rows
          .where((j) => !CacheDatabase.isCacheable(j))
          .map((j) => Message.fromJson(j))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<({List<Message> messages, bool hasMore})> fetchAndCache(
    int chatId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final page = await ChatService.fetchMessages(
      chatId,
      offset: offset,
      limit: limit,
    );
    await CacheDatabase.cacheMessagesRaw(
      chatId,
      page.messages.map((m) => m.toJson()).toList(),
    );
    return (messages: page.messages, hasMore: page.hasMore);
  }

  static Future<({List<Message> messages, bool hasMore})> getOlderMessages(
    int chatId, {
    required int offset,
    int limit = 50,
  }) async {
    try {
      final total = await CacheDatabase.countMessages(chatId);
      if (total >= offset + limit) {
        final rows = await CacheDatabase.loadMessages(
          chatId,
          limit: offset + limit,
        );
        final page = rows
            .take(rows.length - offset)
            .map((j) => Message.fromJson(j))
            .toList();
        return (messages: page, hasMore: offset + limit < total);
      }
    } catch (_) {}
    try {
      return await fetchAndCache(chatId, offset: offset, limit: limit);
    } catch (e) {
      if (isOfflineError(e)) {
        try {
          final rows = await CacheDatabase.loadMessages(
            chatId,
            limit: offset + limit,
          );
          final page = rows
              .where(CacheDatabase.isCacheable)
              .skip(rows.length > offset ? rows.length - offset : 0)
              .map((j) => Message.fromJson(j))
              .toList();
          return (messages: page, hasMore: false);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> cacheIncomingMessage(int chatId, Message message) =>
      CacheDatabase.cacheMessagesRaw(chatId, [message.toJson()]);

  static Future<void> replaceTempWithServer(
    int chatId,
    Message temp,
    Message serverMessage,
  ) => CacheDatabase.replaceTempMessage(
    chatId,
    temp.timeCreate,
    serverMessage.toJson(),
  );

  static Future<void> removeCachedMessage(int chatId, int messageId) =>
      CacheDatabase.deleteMessage(chatId, messageId);

  static Future<void> markChatRead(int chatId) async {
    final myId = await AuthService.getUserId();
    if (myId == null) return;
    await CacheDatabase.markIncomingRead(chatId, myId);
  }

  static Future<void> markOutgoingRead(int chatId, int senderId) =>
      CacheDatabase.markOutgoingRead(chatId, senderId);

  /// Глобальный поиск по сообщениям всех чатов в локальном кэше.
  static Future<List<GlobalSearchHit>> searchMessagesGlobal(
    String query, {
    int limit = 200,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final myPrivateKey = await KeyStorageService.getPrivateKey();
    final rows = await CacheDatabase.searchMessagesGlobal(
      query: trimmed,
      limit: limit,
      decrypt: (json) => MessageCrypto.display(
        (json['content'] ?? '').toString(),
        myPrivateKey,
      ),
    );
    if (rows.isEmpty) return const [];

    final chats = await CacheDatabase.loadChatsJson();
    final chatsById = <int, Map<String, dynamic>>{};
    for (final chat in chats) {
      final id = asInt(chat['chat_id']);
      if (id != null) chatsById[id] = chat;
    }

    final hits = <GlobalSearchHit>[];
    for (final json in rows) {
      final message = Message.fromJson(json);
      final chatId = asInt(json['chat_id']);
      if (chatId == null || message.id == null) continue;

      final content = MessageCrypto.isContainer(message.content)
          ? MessageCrypto.display(message.content, myPrivateKey)
          : message.content;
      final chat = chatsById[chatId];

      hits.add(
        GlobalSearchHit(
          chatId: chatId,
          chatName: (chat?['user_name'] ?? 'Чат').toString(),
          avatarUrl: chat?['avatar_url'] as String?,
          messageId: message.id,
          content: content,
          createdAt: message.createdAt,
        ),
      );
    }

    return hits;
  }

  static Future<List<Message>> searchMessages(
    int chatId, {
    required String query,
    int limit = 100,
  }) async {
    if (query.trim().isEmpty) return const [];
    final myPrivateKey = await KeyStorageService.getPrivateKey();
    final rows = await CacheDatabase.searchMessages(
      chatId,
      query: query,
      limit: limit,
      decrypt: (json) => MessageCrypto.display(
        (json['content'] ?? '').toString(),
        myPrivateKey,
      ),
    );
    return rows.map((j) {
      final m = Message.fromJson(j);
      return MessageCrypto.isContainer(m.content)
          ? m.copyWith(content: MessageCrypto.display(m.content, myPrivateKey))
          : m;
    }).toList();
  }

  static Future<void> cacheProfile(Map<String, dynamic> profileJson) =>
      CacheDatabase.upsertProfile(profileJson);

  static Future<Map<String, dynamic>?> cachedProfile(int userId) =>
      CacheDatabase.loadProfile(userId);

  static Future<void> clearAll() => CacheDatabase.clearAll();
}
