import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../utils/logger.dart';

class CryptoService {
  CryptoService._();

  static const String containerPrefix = 'V2.';

  static const String _curveName = 'secp256r1'; // NIST P-256
  static const int _ephemeralPublicKeyLength = 65; // uncompressed SEC1 point
  static const int _nonceLength = 12; // RFC 7539
  static const int _tagLength = 16; // Poly1305
  static const int _keyLength = 32; // ChaCha20: 256-bit key
  static const String _keyMarker = 'v2:';

  static final Uint8List _wrapNonce = Uint8List(_nonceLength);

  static final Random _rng = Random.secure();
  static FortunaRandom? _random;

  static Uint8List randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static SecureRandom get _secureRandom {
    final cached = _random;
    if (cached != null) return cached;
    final fortuna = FortunaRandom()..seed(KeyParameter(randomBytes(32)));
    _random = fortuna;
    return fortuna;
  }

  static ECDomainParameters get _domain => ECDomainParameters(_curveName);

  static Map<String, String> generateKeyPair() {
    final pair = _generateEphemeralPair();
    final publicKey = pair.publicKey as ECPublicKey;
    final privateKey = pair.privateKey as ECPrivateKey;

    final q = publicKey.Q!.getEncoded(false);

    final publicData = <String, dynamic>{
      'alg': 'ECDSA',
      'crv': _curveName,
      'x': base64Encode(q.sublist(1, 33)),
      'y': base64Encode(q.sublist(33, 65)),
    };

    return {
      'publicKey':
          '$_keyMarker${base64Encode(utf8.encode(jsonEncode(publicData)))}',
      'privateKey':
          '$_keyMarker${base64Encode(_bigIntToBytes(privateKey.d!, 32))}',
    };
  }

  static bool isModernPrivateKey(String encoded) =>
      encoded.startsWith(_keyMarker);

  static ECPrivateKey _decodePrivate(String encoded) {
    if (!isModernPrivateKey(encoded)) {
      throw const FormatException('Legacy RSA private key is not supported');
    }
    final bytes = base64Decode(encoded.substring(_keyMarker.length));
    return ECPrivateKey(_bytesToBigInt(bytes), _domain);
  }

  static ECPublicKey _decodePublic(String encoded) {
    if (isModernPrivateKey(encoded)) {
      final jsonStr = utf8.decode(
        base64Decode(encoded.substring(_keyMarker.length)),
      );
      return _publicKeyFromJsonMap(jsonDecode(jsonStr) as Map<String, dynamic>);
    }

    final decoded = jsonTryDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      if (decoded['alg'] == 'ECDSA') return _publicKeyFromJsonMap(decoded);
      throw const FormatException('Recipient still uses a legacy RSA key');
    }
    throw const FormatException('Malformed public key');
  }

  static Object? jsonTryDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }

  static ECPublicKey _publicKeyFromJsonMap(Map<String, dynamic> data) {
    final x = _bytesToBigInt(base64Decode(data['x'] as String));
    final y = _bytesToBigInt(base64Decode(data['y'] as String));
    return ECPublicKey(_domain.curve.createPoint(x, y), _domain);
  }

  static String encryptMessage(
    String message,
    List<String> recipientsPublicKeys,
  ) {
    try {
      if (recipientsPublicKeys.isEmpty) {
        throw const FormatException('No recipients provided');
      }

      final contentKey = randomBytes(_keyLength);

      final nonce = randomBytes(_nonceLength);
      final sealed = _aead(true, contentKey, nonce, _encodeString(message));
      final encryptedContent = Uint8List(_nonceLength + sealed.length)
        ..setRange(0, _nonceLength, nonce)
        ..setRange(_nonceLength, _nonceLength + sealed.length, sealed);

      final wrapped = <Uint8List>[];
      for (final raw in recipientsPublicKeys) {
        final recipientPub = _decodePublic(raw);
        final ephPair = _generateEphemeralPair();
        final ephPriv = ephPair.privateKey as ECPrivateKey;
        final ephPubBytes = (ephPair.publicKey as ECPublicKey).Q!.getEncoded(
          false,
        );

        final agreement = ECDHBasicAgreement()..init(ephPriv);
        final sharedSecret = agreement.calculateAgreement(recipientPub);
        final wrapKey = _deriveKey(_bigIntToBytes(sharedSecret, 32));

        final wrappedKey = _aead(true, wrapKey, _wrapNonce, contentKey);
        wrapped.add(
          Uint8List(ephPubBytes.length + wrappedKey.length)
            ..setRange(0, ephPubBytes.length, ephPubBytes)
            ..setRange(
              ephPubBytes.length,
              ephPubBytes.length + wrappedKey.length,
              wrappedKey,
            ),
        );
      }

      final body = BytesBuilder(copy: false)
        ..add(_uint16(wrapped.length))
        ..add(_uint16(encryptedContent.length))
        ..add(encryptedContent);
      for (final block in wrapped) {
        body.add(_uint16(block.length));
        body.add(block);
      }

      return '$containerPrefix${base64Encode(body.takeBytes())}';
    } on FormatException {
      rethrow;
    } catch (e) {
      log.e('Encryption error: $e');
      throw CryptoException('Failed to encrypt message', cause: e);
    }
  }

  static String decryptMessage(
    String encryptedBase64,
    String myPrivateKeyEncoded, {
    String Function(String raw)? onLegacyFailure,
  }) {
    try {
      if (!encryptedBase64.startsWith(containerPrefix)) {
        if (onLegacyFailure != null) return onLegacyFailure(encryptedBase64);
        throw const CryptoException('Message uses the legacy encryption');
      }

      final payload = base64Decode(
        encryptedBase64.substring(containerPrefix.length),
      );
      if (payload.length < 4) {
        throw const FormatException('Truncated encrypted container');
      }

      var pos = 0;
      int readU16() {
        if (pos + 2 > payload.length) {
          throw const FormatException('Truncated encrypted container');
        }
        final v = (payload[pos] << 8) | payload[pos + 1];
        pos += 2;
        return v;
      }

      final recipientCount = readU16();
      final contentLength = readU16();
      if (contentLength < _nonceLength + _tagLength ||
          pos + contentLength > payload.length) {
        throw const FormatException('Corrupted encrypted content');
      }
      final encryptedContent = payload.sublist(pos, pos + contentLength);
      pos += contentLength;

      final privKey = _decodePrivate(myPrivateKeyEncoded);
      Object? lastError;
      for (var i = 0; i < recipientCount; i++) {
        final blockLength = readU16();
        if (pos + blockLength > payload.length) {
          throw const FormatException('Corrupted recipient block');
        }
        final block = payload.sublist(pos, pos + blockLength);
        pos += blockLength;

        if (block.length <= _ephemeralPublicKeyLength) continue;
        try {
          final ephPub = ECPublicKey(
            _domain.curve.decodePoint(
              block.sublist(0, _ephemeralPublicKeyLength),
            ),
            _domain,
          );
          final agreement = ECDHBasicAgreement()..init(privKey);
          final sharedSecret = agreement.calculateAgreement(ephPub);
          final wrapKey = _deriveKey(_bigIntToBytes(sharedSecret, 32));

          final contentKey = _aead(
            false,
            wrapKey,
            _wrapNonce,
            Uint8List.fromList(block.sublist(_ephemeralPublicKeyLength)),
          );

          final nonce = encryptedContent.sublist(0, _nonceLength);
          final sealed = encryptedContent.sublist(_nonceLength);
          final plaintext = _aead(
            false,
            contentKey,
            nonce,
            Uint8List.fromList(sealed),
          );
          return _decodeString(plaintext);
        } catch (e) {
          lastError = e;
        }
      }
      throw CryptoException(
        'No key slot matches this message',
        cause: lastError,
      );
    } on CryptoException {
      rethrow;
    } catch (e) {
      log.w('Decryption error: $e');
      throw CryptoException('Failed to decrypt message', cause: e);
    }
  }

  static bool isOurContainer(String content) =>
      content.startsWith(containerPrefix);

  static String sign(String data, String myPrivateKeyEncoded) {
    try {
      final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
        ..init(
          true,
          PrivateKeyParameter<ECPrivateKey>(
            _decodePrivate(myPrivateKeyEncoded),
          ),
        );

      final sig = signer.generateSignature(_encodeString(data)) as ECSignature;
      return base64Encode(
        Uint8List.fromList([
          ..._bigIntToBytes(sig.r, 32),
          ..._bigIntToBytes(sig.s, 32),
        ]),
      );
    } catch (e) {
      log.e('Signing error: $e');
      throw CryptoException('Failed to sign message', cause: e);
    }
  }

  static bool verify(
    String data,
    String signatureBase64,
    String senderPublicKey,
  ) {
    try {
      final raw = base64Decode(signatureBase64);
      if (raw.length != 64) return false;

      final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
        ..init(
          false,
          PublicKeyParameter<ECPublicKey>(_decodePublic(senderPublicKey)),
        );

      return signer.verifySignature(
        _encodeString(data),
        ECSignature(
          _bytesToBigInt(raw.sublist(0, 32)),
          _bytesToBigInt(raw.sublist(32, 64)),
        ),
      );
    } catch (e) {
      log.w('Verification error: $e');
      return false;
    }
  }

  static AsymmetricKeyPair _generateEphemeralPair() {
    final keyGen = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(_domain), _secureRandom),
      );
    return keyGen.generateKeyPair();
  }

  static const List<int> _hkdfSalt = <int>[
    0x4f,
    0x72,
    0x62,
    0x69,
    0x74,
    0x61,
    0x2d,
    0x45,
    0x43,
    0x49,
    0x45,
    0x53,
    0x2d,
    0x76,
    0x32,
    0x00,
  ];
  static const List<int> _hkdfInfo = <int>[
    0x6d,
    0x65,
    0x73,
    0x73,
    0x61,
    0x67,
    0x65,
    0x2d,
    0x6b,
    0x65,
    0x79,
    0x7c,
    0x4f,
    0x9a,
    0x1d,
    0x5b,
  ];

  static HMac _hmacSha256(Uint8List key) =>
      HMac(SHA256Digest(), 64)..init(KeyParameter(key));

  static Uint8List _deriveKey(Uint8List sharedSecret) {
    final prkMac = _hmacSha256(Uint8List.fromList(_hkdfSalt));
    final prkBytes = Uint8List(prkMac.macSize);
    prkMac.update(sharedSecret, 0, sharedSecret.length);
    prkMac.doFinal(prkBytes, 0);

    final hmac = _hmacSha256(prkBytes);
    final info = Uint8List.fromList(_hkdfInfo);
    final okm = Uint8List(_keyLength);
    var previous = Uint8List(0);
    var offset = 0;
    var counter = 1;
    while (offset < _keyLength) {
      hmac
        ..reset()
        ..update(previous, 0, previous.length)
        ..update(info, 0, info.length)
        ..update(Uint8List.fromList([counter]), 0, 1);
      final block = Uint8List(hmac.macSize);
      hmac.doFinal(block, 0);
      final take = (_keyLength - offset < block.length)
          ? _keyLength - offset
          : block.length;
      okm.setRange(offset, offset + take, block);
      offset += take;
      previous = block;
      counter++;
    }
    return okm;
  }

  static Uint8List _aead(
    bool forEncryption,
    Uint8List key,
    Uint8List nonce,
    Uint8List input,
  ) {
    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        forEncryption,
        AEADParameters(KeyParameter(key), _tagLength * 8, nonce, Uint8List(0)),
      );

    final output = Uint8List(cipher.getOutputSize(input.length));
    final processed = cipher.processBytes(input, 0, input.length, output, 0);
    final tailLen = cipher.doFinal(output, processed);
    return output.sublist(0, processed + tailLen);
  }

  static Uint8List _uint16(int value) =>
      Uint8List.fromList([(value >> 8) & 0xff, value & 0xff]);

  static Uint8List _encodeString(String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;
    return Uint8List.fromList([
      (length >> 24) & 0xff,
      (length >> 16) & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
      ...bytes,
    ]);
  }

  static String _decodeString(Uint8List data) {
    if (data.length < 4) throw const FormatException('Corrupted plaintext');
    final length = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    if (length < 0 || length > data.length - 4) {
      throw const FormatException('Corrupted plaintext length');
    }
    return utf8.decode(data.sublist(4, 4 + length));
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte & 0xff);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final out = Uint8List(length);
    var v = value;
    final mask = BigInt.from(0xff);
    for (var i = length - 1; i >= 0; i--) {
      out[i] = (v & mask).toInt();
      v = v >> 8;
    }
    return out;
  }
}

class CryptoException implements Exception {
  const CryptoException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'CryptoException: $message${cause == null ? '' : ' ($cause)'}';
}
