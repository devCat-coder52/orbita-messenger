import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class KeyStorageService {
  static const String _publicKeyKey = 'user_public_key';
  static const String _privateKeyKey = 'user_private_key';
  static String? _cachedPrivateKey;

  static Future<void> initializeKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final String? publicKey = prefs.getString(_publicKeyKey);
    String? privateKey = _cachedPrivateKey;

    if (publicKey == null || privateKey == null) {
      log.i('🔑 Ключи не найдены локально. Генерируем новую пару...');
      final keys = CryptoService.generateKeyPair();
      final newPublicKey = keys['publicKey']!;
      privateKey = keys['privateKey']!;

      await prefs.setString(_publicKeyKey, newPublicKey);
      _cachedPrivateKey = privateKey;
    }

    await updatePublicKey(publicKey ?? prefs.getString(_publicKeyKey)!);
  }

  static Future<String?> getPrivateKey() async {
    return _cachedPrivateKey;
  }

  static Future<String?> getPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicKeyKey);
  }

  static Future<void> clear() async {
    _cachedPrivateKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_publicKeyKey);
    await prefs.remove(_privateKeyKey);
  }

  static Future<void> updatePublicKey(String publicKey) async {
    try {
      await HttpService.client.post(
        '/users/public-key',
        data: {'public_key': publicKey},
      );
    } catch (e) {
      log.e('Ошибка отправки ключа на сервер: $e');
    }
  }
}
