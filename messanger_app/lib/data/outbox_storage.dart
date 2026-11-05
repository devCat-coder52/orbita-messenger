import '../services/socket_service.dart';
import '../utils/logger.dart';
import 'cache_database.dart';

class SqliteOutboxStorage implements OutboxStorage {
  const SqliteOutboxStorage();

  @override
  Future<List<OutboxMessage>> load() async {
    try {
      final rows = await CacheDatabase.loadOutboxJson();
      return rows
          .map(OutboxMessage.fromJson)
          .whereType<OutboxMessage>()
          .toList();
    } catch (e) {
      log.w('Outbox: не удалось прочитать очередь из кэша: $e');
      return const [];
    }
  }

  @override
  Future<void> save(OutboxMessage message) =>
      CacheDatabase.saveOutboxMessage(message.toJson());

  @override
  Future<void> remove(int timeCreate) =>
      CacheDatabase.deleteOutboxMessage(timeCreate);

  @override
  Future<void> clear() => CacheDatabase.clearOutbox();
}
