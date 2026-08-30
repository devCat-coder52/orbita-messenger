import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/logger.dart';

class CryptoService {
  static final SecureRandom _secureRandom = FortunaRandom();

  static Map<String, String> generateKeyPair() {
    final seed = _generateSeed(32);
    _secureRandom.seed(KeyParameter(seed));

    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 4096, 64),
          _secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final publicData = {
      'modulus': publicKey.modulus!.toRadixString(16),
      'exponent': publicKey.exponent!.toRadixString(16),
    };

    return {
      'publicKey': jsonEncode(publicData),
      'privateKey': _encodePrivateKey(privateKey),
    };
  }

  static Uint8List _generateSeed(int length) {
    final seed = Uint8List(length);
    for (int i = 0; i < length; i++) {
      seed[i] = DateTime.now().microsecondsSinceEpoch % 256;
    }
    return seed;
  }

  static String _encodePrivateKey(RSAPrivateKey key) {
    final data = {
      'modulus': key.modulus!.toRadixString(16),
      'privateExponent': key.privateExponent!.toRadixString(16),
      'p': key.p!.toRadixString(16),
      'q': key.q!.toRadixString(16),
    };
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  static RSAPrivateKey _decodePrivateKey(String encoded) {
    final jsonStr = utf8.decode(base64Decode(encoded));
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    return RSAPrivateKey(
      BigInt.parse(data['modulus'] as String, radix: 16),
      BigInt.parse(data['privateExponent'] as String, radix: 16),
      BigInt.parse(data['p'] as String, radix: 16),
      BigInt.parse(data['q'] as String, radix: 16),
    );
  }

  static RSAPublicKey _decodePublicKey(String encoded) {
    final data = jsonDecode(encoded) as Map<String, dynamic>;

    return RSAPublicKey(
      BigInt.parse(data['modulus'] as String, radix: 16),
      BigInt.parse(data['exponent'] as String, radix: 16),
    );
  }

  static String encryptMessage(String message, String recipientPublicKeyJson) {
    try {
      final publicKey = _decodePublicKey(recipientPublicKeyJson);
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.RSA(publicKey: publicKey),
      );
      final encrypted = encrypter.encrypt(message);
      return encrypted.base64;
    } catch (e) {
      log.e('Encryption error: $e');
      throw Exception('Failed to encrypt message');
    }
  }

  static String decryptMessage(
    String encryptedBase64,
    String myPrivateKeyEncoded,
  ) {
    try {
      final privateKey = _decodePrivateKey(myPrivateKeyEncoded);
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.RSA(privateKey: privateKey),
      );
      final encrypted = encrypt_pkg.Encrypted.fromBase64(encryptedBase64);
      return encrypter.decrypt(encrypted);
    } catch (e) {
      log.e('Decryption error: $e');
      throw Exception('Failed to decrypt message');
    }
  }
}
