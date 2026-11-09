/// Найденное сообщение в глобальном поиске: текст, чат и время.
class GlobalSearchHit {
  const GlobalSearchHit({
    required this.chatId,
    required this.chatName,
    required this.avatarUrl,
    required this.messageId,
    required this.content,
    required this.createdAt,
  });

  final int? chatId;
  final String chatName;
  final String? avatarUrl;
  final int? messageId;
  final String content;
  final DateTime createdAt;
}
