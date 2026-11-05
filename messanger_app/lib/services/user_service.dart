import 'auth_service.dart';
import '../utils/logger.dart';

class UserService {
  static String baseUrl = '/users';
  static const _cacheTtl = Duration(minutes: 10);
  static final Map<int, ({String key, DateTime at})> _cache = {};

  static Future<String?> getPublicKey(int userId) async {
    final cached = _cache[userId];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.key;
    }

    log.i('Пытаемся получить код шифрования');
    try {
      final res = await HttpService.client.get('/users/$userId/public-key');

      final key = res.data is Map ? res.data['public_key'] : null;
      if (key is String && key.isNotEmpty) {
        _cache[userId] = (key: key, at: DateTime.now());
        return key;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getUserById(int userId) async {
    final response = await HttpService.client.get('$baseUrl/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> getUserByChat(int chatId) async {
    final response = await HttpService.client.get('/chat/$chatId/info');
    return response.data;
  }

  void clearCache() {
    _cache.clear();
  }
}
