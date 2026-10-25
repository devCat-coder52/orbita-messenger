import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../utils/logger.dart';

class CacheDatabase {
  static const _dbName = 'orbita_cache.db';
  static const _dbVersion = 3;

  static bool isCacheable(Map<String, dynamic> json) =>
      json['is_temp'] != true && json['is_temp'] != 1;

  static const maxCachedMessagesPerChat = 500;
  static const maxCachedChats = 300;

  static Database? _db;
  static Future<Database>? _opening;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _opening ??= _open();
    _db = await _opening!;
    return _db!;
  }

  static const _chatsSchemaSql = '''
    CREATE TABLE chats (
      chat_id INTEGER PRIMARY KEY,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  static const _messagesSchemaSql = '''
    CREATE TABLE messages (
      rowid INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER,
      chat_id INTEGER NOT NULL,
      time_create INTEGER NOT NULL,
      data TEXT NOT NULL,
      is_temp INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _profilesSchemaSql = '''
    CREATE TABLE profiles (
      user_id INTEGER PRIMARY KEY,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  static const _messagesIndexesSql = [
    'CREATE INDEX idx_messages_chat_time ON messages(chat_id, time_create)',
    'CREATE UNIQUE INDEX uq_messages_chat_mid '
        'ON messages(chat_id, message_id) WHERE message_id IS NOT NULL',
  ];

  static Future<void> _createAll(Database db) async {
    await db.execute(_chatsSchemaSql);
    await db.execute(_messagesSchemaSql);
    for (final sql in _messagesIndexesSql) {
      await db.execute(sql);
    }
    await db.execute(_profilesSchemaSql);
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    Future<bool> tableExists(String table) async {
      final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      return r.isNotEmpty;
    }

    if (!await tableExists('chats')) {
      await db.execute(_chatsSchemaSql);
    }
    if (!await tableExists('messages')) {
      await db.execute(_messagesSchemaSql);
    } else {
      final idx = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='messages'",
      );
      final names = idx.map((e) => e['name'] as String).toSet();
      if (!names.contains('idx_messages_chat_time')) {
        await db.execute(_messagesIndexesSql[0]);
      }
      if (!names.contains('uq_messages_chat_mid')) {
        await db.execute(_messagesIndexesSql[1]);
      }
    }
    if (!await tableExists('profiles')) {
      await db.execute(_profilesSchemaSql);
    }
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    try {
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) => _createAll(db),
        onUpgrade: _upgrade,
      );
    } catch (e) {
      log.w('CacheDatabase: БД кэша повреждена, пересоздаём: $e');
      final factory = databaseFactory;
      await factory.deleteDatabase(path);
      return openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) => _createAll(db),
        onUpgrade: _upgrade,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> loadChatsJson() async {
    final db = await database;
    final rows = await db.query('chats', orderBy: 'updated_at DESC');
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> upsertChats(List<Map<String, dynamic>> chatsJson) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final c in chatsJson) {
      final chatId = c['chat_id'];
      if (chatId == null) continue;
      batch.insert('chats', {
        'chat_id': chatId,
        'data': jsonEncode(c),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await trimChats();
  }

  static Future<void> upsertChat(Map<String, dynamic> chatJson) =>
      upsertChats([chatJson]);

  static Future<void> deleteChat(int chatId) async {
    final db = await database;
    await db.delete('chats', where: 'chat_id = ?', whereArgs: [chatId]);
    await deleteAllMessages(chatId);
  }

  static Future<void> replaceAllChats(
    List<Map<String, dynamic>> chatsJson,
  ) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    batch.delete('chats');
    for (final c in chatsJson) {
      final chatId = c['chat_id'];
      if (chatId == null) continue;
      batch.insert('chats', {
        'chat_id': chatId,
        'data': jsonEncode(c),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await trimChats();
  }

  static Future<void> trimChats() async {
    final db = await database;
    await db.rawDelete(
      'DELETE FROM chats WHERE chat_id NOT IN '
      '(SELECT chat_id FROM chats ORDER BY updated_at DESC LIMIT ?)',
      [maxCachedChats],
    );
    await db.execute(
      'DELETE FROM messages WHERE chat_id NOT IN (SELECT chat_id FROM chats)',
    );
  }

  static Future<void> cacheMessagesRaw(
    int chatId,
    List<Map<String, dynamic>> messagesJson,
  ) async {
    if (messagesJson.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final m in messagesJson) {
      final mid = switch (m['id']) {
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      };
      batch.insert('messages', {
        'message_id': mid,
        'chat_id': chatId,
        'time_create': switch (m['time_create']) {
          final int v => v,
          final String v => int.tryParse(v) ?? 0,
          _ => 0,
        },
        'data': jsonEncode(m),
        'is_temp': m['is_temp'] == true ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await trimChat(chatId);
  }

  static Future<void> patchChatPreview(
    int chatId,
    Map<String, dynamic> fields,
  ) async {
    final db = await database;
    final rows = await db.query(
      'chats',
      columns: ['data'],
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
    if (rows.isEmpty) return;
    final data =
        jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    data.addAll(fields);
    await db.update(
      'chats',
      {
        'data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }

  static Future<List<Map<String, dynamic>>> loadMessages(
    int chatId, {
    required int limit,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'time_create DESC, rowid DESC',
      limit: limit,
      offset: offset,
    );
    return rows.reversed
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  static Future<int> countPersistentMessages(int chatId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE chat_id = ? '
      'AND message_id IS NOT NULL',
      [chatId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  static Future<int> countMessages(int chatId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE chat_id = ?',
      [chatId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  static Future<void> updateMessageStatus(
    int chatId,
    int messageId,
    String status,
  ) async {
    final db = await database;
    await db.rawUpdate(
      "UPDATE messages SET data = json_set(data, '\$.status', ?) "
      'WHERE chat_id = ? AND message_id = ?',
      [status, chatId, messageId],
    );
  }

  static Future<void> replaceTempMessage(
    int chatId,
    int timeCreate,
    Map<String, dynamic> serverJson,
  ) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'chat_id = ? AND time_create = ? AND message_id IS NULL',
      whereArgs: [chatId, timeCreate],
    );
    await cacheMessagesRaw(chatId, [serverJson]);
  }

  static Future<List<Map<String, dynamic>>> searchMessages(
    int chatId, {
    required String query,
    required String Function(Map<String, dynamic> json) decrypt,
    int limit = 100,
  }) async {
    if (query.isEmpty) return const [];
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'time_create DESC, rowid DESC',
    );
    final needle = query.toLowerCase();
    final result = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (result.length >= limit) break;
      final data = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      final text = decrypt(data).toLowerCase();
      if (text.contains(needle)) result.add(data);
    }
    return result;
  }

  static Future<Map<String, dynamic>?> findMessage(
    int chatId,
    int messageId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: ['data'],
      where: 'chat_id = ? AND message_id = ?',
      whereArgs: [chatId, messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  static Future<void> _markRead({
    required int chatId,
    required int senderId,
    required bool incoming,
  }) async {
    final db = await database;
    final senderExpr =
        "COALESCE(json_extract(data, '\$.sender.id'), "
        "json_extract(data, '\$.sender_id'))";
    final rows = await db.rawQuery(
      'SELECT rowid, data FROM messages '
      "WHERE chat_id = ? AND message_id IS NOT NULL "
      "AND COALESCE(json_extract(data, '\$.status'), '') != 'read' "
      'AND $senderExpr ${incoming ? '!=' : '='} ?',
      [chatId, senderId],
    );
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      data['status'] = 'read';
      batch.update(
        'messages',
        {'data': jsonEncode(data)},
        where: 'rowid = ?',
        whereArgs: [row['rowid']],
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> markOutgoingRead(int chatId, int senderId) =>
      _markRead(chatId: chatId, senderId: senderId, incoming: false);

  static Future<void> markIncomingRead(int chatId, int myUserId) =>
      _markRead(chatId: chatId, senderId: myUserId, incoming: true);

  static Future<void> deleteMessage(int chatId, int messageId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'chat_id = ? AND message_id = ?',
      whereArgs: [chatId, messageId],
    );
  }

  static Future<void> deleteAllMessages(int chatId) async {
    final db = await database;
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  static Future<void> trimChat(int chatId) async {
    final db = await database;
    await db.rawDelete(
      'DELETE FROM messages WHERE chat_id = ? AND rowid NOT IN '
      '(SELECT rowid FROM messages WHERE chat_id = ? '
      'ORDER BY time_create DESC, rowid DESC LIMIT ?)',
      [chatId, chatId, maxCachedMessagesPerChat],
    );
  }

  static Future<void> upsertProfile(Map<String, dynamic> profileJson) async {
    final userId = switch (profileJson['id'] ?? profileJson['user_id']) {
      final int v => v,
      final String v => int.tryParse(v),
      _ => null,
    };
    if (userId == null) return;
    final db = await database;
    await db.insert('profiles', {
      'user_id': userId,
      'data': jsonEncode(profileJson),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> loadProfile(int userId) async {
    final db = await database;
    try {
      final rows = await db.query(
        'profiles',
        columns: ['data'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('chats');
    await db.delete('messages');
    await db.delete('profiles');
  }
}
