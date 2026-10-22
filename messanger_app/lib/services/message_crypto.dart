import 'crypto_service.dart';
import 'key_storage_service.dart';
import 'user_service.dart';
import '../utils/logger.dart';

class MessageCrypto {
  MessageCrypto._();

  static const String _placeholder = '[Зашифровано]';

  static Future<String> encrypt(String plainText, int? peerId) async {
    if (plainText.isEmpty || peerId == null) return plainText;
    try {
      final recipientPublicKey = await UserService.getPublicKey(peerId);
      final myPublicKey = await KeyStorageService.getPublicKey();
      if (recipientPublicKey == null || myPublicKey == null) {
        log.w('No key pair available for user $peerId — sending unencrypted');
        return plainText;
      }
      return CryptoService.encryptMessage(plainText, [
        recipientPublicKey,
        myPublicKey,
      ]);
    } catch (e) {
      log.e('Message encryption failed: $e');
      return plainText;
    }
  }

  static String decryptInbound(String content, String myPrivateKey) =>
      CryptoService.decryptMessage(
        content,
        myPrivateKey,
        onLegacyFailure: (_) => _placeholder,
      );

  static String display(String content, String? myPrivateKey) {
    if (!isContainer(content)) return content;
    try {
      return decryptInbound(content, myPrivateKey ?? '');
    } catch (_) {
      return _placeholder;
    }
  }

  static bool isContainer(String content) =>
      content.startsWith(CryptoService.containerPrefix);

  static String get placeholder => _placeholder;
}
