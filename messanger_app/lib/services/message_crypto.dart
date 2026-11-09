import 'crypto_service.dart';
import 'key_storage_service.dart';
import 'user_service.dart';

class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'EncryptionUnavailableException: $message';
}

class EncryptResult {
  const EncryptResult(this.content, {required this.encrypted});
  final String content;
  final bool encrypted;
}

class MessageCrypto {
  MessageCrypto._();

  static const String _placeholder = '[Зашифровано]';

  static Future<EncryptResult> encryptWithStatus(
    String plainText,
    int? peerId,
  ) async {
    if (plainText.isEmpty || peerId == null) {
      return EncryptResult(plainText, encrypted: false);
    }
    final recipientPublicKey = await UserService.getPublicKey(peerId);
    final myPublicKey = await KeyStorageService.getPublicKey();
    if (recipientPublicKey == null || myPublicKey == null) {
      throw const EncryptionUnavailableException(
        'Нет публичного ключа собеседника — сообщение не может быть '
        'отправлено в незашифрованном виде',
      );
    }
    final container = CryptoService.encryptMessage(plainText, [
      recipientPublicKey,
      myPublicKey,
    ]);
    return EncryptResult(container, encrypted: true);
  }

  static Future<String> encrypt(String plainText, int? peerId) async {
    final result = await encryptWithStatus(plainText, peerId);
    if (!result.encrypted && plainText.isNotEmpty && peerId != null) {
      throw const EncryptionUnavailableException(
        'Шифрование недоступно — отправка отменена',
      );
    }
    return result.content;
  }

  static String decryptInbound(String content, String myPrivateKey) =>
      CryptoService.decryptMessage(
        content,
        myPrivateKey,
        onLegacyFailure: (_) => _placeholder,
      );

  /// Кэш расшифрованного текста: при повторном открытии чата те же
  /// сообщения не проходят ECDH-расшифровку заново.
  static final Map<String, String> _displayCache = <String, String>{};
  static const int _displayCacheLimit = 1000;

  static String display(String content, String? myPrivateKey) {
    if (!isContainer(content)) return content;

    final cached = _displayCache[content];
    if (cached != null) return cached;

    String text;
    try {
      text = decryptInbound(content, myPrivateKey ?? '');
    } catch (_) {
      text = _placeholder;
    }

    if (_displayCache.length >= _displayCacheLimit) {
      _displayCache.remove(_displayCache.keys.first);
    }
    _displayCache[content] = text;
    return text;
  }

  /// Сбрасываем кэш при выходе/смене ключей — текст стал неактуален.
  static void clearDisplayCache() => _displayCache.clear();

  static bool isContainer(String content) =>
      content.startsWith(CryptoService.containerPrefix);

  static String get placeholder => _placeholder;
}
