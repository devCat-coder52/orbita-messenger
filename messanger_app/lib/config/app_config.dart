import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Единая точка доступа к адресам сервера.
///
/// Режим определяется наличием `BASE_URL` в `--dart-define`:
///   - задан  → релизная сборка, остальные адреса выводятся из него;
///   - не задан → локальная разработка, всё читается из `.env`.
///
/// Так `.env` с адресом домашней сети не протекает в релизный APK:
///   flutter run
///   flutter build apk --release --dart-define=BASE_URL=https://api.orbita.ru
abstract final class AppConfig {
  static const String _baseUrlDefine = String.fromEnvironment('BASE_URL');
  static const String _socketUrlDefine = String.fromEnvironment('SOCKET_URL');
  static const String _baseUrlApiDefine = String.fromEnvironment('BASE_URL_API');

  /// Сборка собрана с явными адресами, а не с `.env`.
  static bool get _isRelease => _baseUrlDefine.isNotEmpty;

  /// Корень API без завершающего слэша: `https://api.orbita.ru`.
  static String get baseUrl => _isRelease
      ? _trim(_baseUrlDefine)
      : _trim(_fromEnv('BASE_URL') ?? '');

  /// Адрес Socket.IO. По умолчанию совпадает с [baseUrl].
  static String get socketUrl {
    if (_isRelease) {
      return _socketUrlDefine.isNotEmpty ? _trim(_socketUrlDefine) : baseUrl;
    }
    final value = _trim(_fromEnv('SOCKET_URL') ?? '');
    return value.isEmpty ? baseUrl : value;
  }

  /// REST-база: `https://api.orbita.ru/api`.
  static String get baseUrlApi {
    if (_isRelease) {
      return _baseUrlApiDefine.isNotEmpty
          ? _trim(_baseUrlApiDefine)
          : '$baseUrl/api';
    }
    final fromEnv = _trim(_fromEnv('BASE_URL_API') ?? '');
    return fromEnv.isNotEmpty ? fromEnv : '$baseUrl/api';
  }

  /// `.env` может быть не загружен — например, в юнит-тестах без `main()`.
  static String? _fromEnv(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  static String _trim(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
