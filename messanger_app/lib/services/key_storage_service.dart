import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_service.dart';
import 'auth_service.dart';
import 'message_crypto.dart';
import '../utils/logger.dart';

class KeyStorageService {
  static const String _publicKeyKey = 'user_public_key';
  static const String _privateKeyKey = 'user_private_key';

  static int? _currentUserId;
  static String? _cachedPrivateKey;
  static String? _cachedPublicKey;

  static String _publicKeyFor(int userId) => '${_publicKeyKey}_$userId';
  static String _privateKeyFor(int userId) => '${_privateKeyKey}_$userId';

  static Future<void> initializeKeys({int? userId}) async {
    final id = userId ?? await AuthService.getUserId();
    if (id == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedPublic = prefs.getString(_publicKeyFor(id));
    final storedPrivate = prefs.getString(_privateKeyFor(id));

    if (storedPublic == null ||
        storedPrivate == null ||
        storedPrivate.isEmpty) {
      log.i('🔑 Ключи не найдены локально. Генерируем новую пару...');
      final generated = CryptoService.generateKeyPair();
      final newPublic = generated['publicKey']!;
      final newPrivate = generated['privateKey']!;

      await prefs.setString(_publicKeyFor(id), newPublic);
      await prefs.setString(_privateKeyFor(id), newPrivate);

      MessageCrypto.clearDisplayCache();
      _apply(id, newPublic, newPrivate);
      await updatePublicKey(newPublic);
      return;
    }

    _apply(id, storedPublic, storedPrivate);
    await updatePublicKey(storedPublic);
  }

  static void _apply(int userId, String publicKey, String privateKey) {
    _currentUserId = userId;
    _cachedPublicKey = publicKey;
    _cachedPrivateKey = privateKey;
  }

  static Future<String?> getPrivateKey() async {
    final cached = _cachedPrivateKey;
    if (cached != null) return cached;

    final id = await AuthService.getUserId();
    if (id == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final loaded = prefs.getString(_privateKeyFor(id));
    if (loaded != null && loaded.isNotEmpty) {
      _currentUserId = id;
      _cachedPrivateKey = loaded;
      _cachedPublicKey = prefs.getString(_publicKeyFor(id));
    }
    return loaded;
  }

  static Future<String?> getPublicKey() async {
    final cached = _cachedPublicKey;
    if (cached != null) return cached;

    final id = await AuthService.getUserId();
    if (id == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final loaded = prefs.getString(_publicKeyFor(id));
    if (loaded != null) {
      _currentUserId = id;
      _cachedPublicKey = loaded;
    }
    return loaded;
  }

  static Future<void> forgetSession() async {
    MessageCrypto.clearDisplayCache();
    _currentUserId = null;
    _cachedPrivateKey = null;
    _cachedPublicKey = null;
  }

  static Future<void> clear() async {
    final id = _currentUserId ?? await AuthService.getUserId();
    await forgetSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_publicKeyKey);
    await prefs.remove(_privateKeyKey);
    if (id != null) {
      await prefs.remove(_publicKeyFor(id));
      await prefs.remove(_privateKeyFor(id));
    }
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
