import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class KeyStorageService {
  static const String _publicKeyKey = 'user_public_key';
  static const String _privateKeyKey = 'user_private_key';

  static Future<void> initializeKeys() async {
    final prefs = await SharedPreferences.getInstance();
    String? publicKey = prefs.getString(_publicKeyKey);
    String? privateKey = prefs.getString(_privateKeyKey);

    if (publicKey == null || privateKey == null) {
      log.i('🔑 Ключи не найдены локально. Генерируем новую пару...');
      final keys = CryptoService.generateKeyPair();
      publicKey = keys['publicKey'];
      privateKey = keys['privateKey'];

      await prefs.setString(_publicKeyKey, publicKey!);
      await prefs.setString(_privateKeyKey, privateKey!);
    }

    await updatePublicKey(publicKey!);
  }

  static Future<String?> getPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_privateKeyKey);
  }

  static Future<String?> getPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicKeyKey);
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
