import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../utils/json_utils.dart';
import '../utils/logger.dart';

class CacheDatabase {
  static const _dbName = 'orbita_cache.db';
  static const _dbVersion = 6;

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
      is_temp INTEGER NOT NULL DEFAULT 0,
      sender_id INTEGER,
      status TEXT
    )
  ''';

  static const _profilesSchemaSql = '''
    CREATE TABLE profiles (
      user_id INTEGER PRIMARY KEY,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  static const _outboxSchemaSql = '''
    CREATE TABLE outbox (
      time_create INTEGER PRIMARY KEY,
      payload TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''';

  static const _messagesIndexesSql = [
    'CREATE INDEX idx_messages_chat_time ON messages(chat_id, time_create)',
    'CREATE UNIQUE INDEX uq_messages_chat_mid '
        'ON messages(chat_id, message_id) WHERE message_id IS NOT NULL',
    'CREATE INDEX idx_messages_chat_status ON messages(chat_id, status)',
  ];

  static Future<void> _createAll(Database db) async {
    await db.execute(_chatsSchemaSql);
    await db.execute(_messagesSchemaSql);
    for (final sql in _messagesIndexesSql) {
      await db.execute(sql);
    }
    await db.execute(_profilesSchemaSql);
    await db.execute(_outboxSchemaSql);
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

      if (oldVersion < 6) {
        final columns = await db.rawQuery('PRAGMA table_info(messages)');
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        if (!columnNames.contains('sender_id')) {
          await db.execute('ALTER TABLE messages ADD COLUMN sender_id INTEGER');
        }
        if (!columnNames.contains('status')) {
          await db.execute('ALTER TABLE messages ADD COLUMN status TEXT');
        }

        // Один раз заполняем колонки из JSON, чтобы дальше фильтровать
        // статусы без разбора всех сообщений.
        final rows = await db.query('messages', columns: ['rowid', 'data']);
        final batch = db.batch();
        for (final row in rows) {
          try {
            final data =
                jsonDecode(row['data'] as String) as Map<String, dynamic>;
            final sender = data['sender'];
            final raw = sender is Map ? sender['id'] : data['sender_id'];
            batch.update(
              'messages',
              {
                'sender_id': switch (raw) {
                  final int v => v,
                  final String v => int.tryParse(v),
                  _ => null,
                },
                'status': data['status']?.toString(),
              },
              where: 'rowid = ?',
              whereArgs: [row['rowid']],
            );
          } catch (_) {}
        }
        await batch.commit(noResult: true);

        if (!names.contains('idx_messages_chat_status')) {
          await db.execute(_messagesIndexesSql[2]);
        }
      }
    }
    if (!await tableExists('profiles')) {
      await db.execute(_profilesSchemaSql);
    }
    if (!await tableExists('outbox')) {
      await db.execute(_outboxSchemaSql);
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

  static int? _senderIdOf(Map<String, dynamic> m) {
    final sender = m['sender'];
    final raw = sender is Map ? sender['id'] : m['sender_id'];
    return switch (raw) {
      final int v => v,
      final String v => int.tryParse(v),
      _ => null,
    };
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
        'sender_id': _senderIdOf(m),
        'status': m['status']?.toString(),
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

  static Future<int> countMessages(int chatId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE chat_id = ?',
      [chatId],
    );
    return (r.first['c'] as int?) ?? 0;
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

  /// Поиск по всем закэшированным сообщениям всех чатов.
  ///
  /// Сквозное шифрование не позволяет искать на сервере, поэтому глобальный
  /// поиск идёт по локальному кэшу.
  static Future<List<Map<String, dynamic>>> searchMessagesGlobal({
    required String query,
    required String Function(Map<String, dynamic> json) decrypt,
    int limit = 200,
  }) async {
    if (query.isEmpty) return const [];

    final db = await database;
    // Ограничиваем окно сканирования: расшифровывать всю базу на каждый
    // запрос слишком дорого для UI-потока.
    final rows = await db.query(
      'messages',
      orderBy: 'time_create DESC, rowid DESC',
      limit: 5000,
    );

    final needle = query.toLowerCase();
    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      if (result.length >= limit) break;
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      final text = decrypt(data).toLowerCase();
      if (!text.contains(needle)) continue;
      data['chat_id'] = row['chat_id'];
      result.add(data);
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
    // На части устройств SQLite собран без JSON1 (json_extract), поэтому
    // разбираем JSON в Dart, а не в SQL.
    final rows = await db.rawQuery(
      'SELECT rowid, data, sender_id, status FROM messages '
      'WHERE chat_id = ? AND message_id IS NOT NULL',
      [chatId],
    );
    if (rows.isEmpty) return;

    final batch = db.batch();
    var changed = false;

    for (final row in rows) {
      if (row['status']?.toString() == 'read') continue;

      var rowSenderId = switch (row['sender_id']) {
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      };

      Map<String, dynamic>? data;
      if (rowSenderId == null) {
        // Старая строка без колонки sender_id — достаём из JSON.
        try {
          data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final sender = data['sender'];
        final rawSender = sender is Map ? sender['id'] : data['sender_id'];
        rowSenderId = int.tryParse(rawSender?.toString() ?? '');
      }
      if (rowSenderId == null) continue;

      final matches = incoming
          ? rowSenderId != senderId
          : rowSenderId == senderId;
      if (!matches) continue;

      if (data == null) {
        try {
          data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
      }
      data['status'] = 'read';
      batch.update(
        'messages',
        {'data': jsonEncode(data), 'status': 'read'},
        where: 'rowid = ?',
        whereArgs: [row['rowid']],
      );
      changed = true;
    }

    if (changed) await batch.commit(noResult: true);
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
    await db.delete('outbox');
  }

  static Future<List<Map<String, dynamic>>> loadOutboxJson() async {
    final db = await database;
    final rows = await db.query('outbox', orderBy: 'time_create ASC');
    return rows
        .map((r) => jsonDecode(r['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> saveOutboxMessage(Map<String, dynamic> json) async {
    final key = asInt(json['time_create']);
    if (key == null) return;
    final db = await database;
    await db.insert('outbox', {
      'time_create': key,
      'payload': jsonEncode(json),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteOutboxMessage(int timeCreate) async {
    final db = await database;
    await db.delete(
      'outbox',
      where: 'time_create = ?',
      whereArgs: [timeCreate],
    );
  }

  static Future<void> clearOutbox() async {
    final db = await database;
    await db.delete('outbox');
  }
}
