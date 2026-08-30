import 'package:dio/dio.dart';
import 'notification_service.dart';
import 'key_storage_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HttpService {
  static late Dio dio;

  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: '${dotenv.env['BASE_URL_API']}',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getToken();

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          log.e("Dio Error: ${e.response?.statusCode} - ${e.message}");

          String errorMessage = 'Произошла ошибка';

          if (e.response != null) {
            final errorData = e.response?.data;
            if (errorData is Map && errorData.containsKey('error')) {
              errorMessage = errorData['error'];
            } else if (e.response?.statusCode == 401) {
              errorMessage = 'Необходимо авторизоваться';
            } else if (e.response?.statusCode == 403) {
              errorMessage = 'Доступ запрещён';
            } else if (e.response?.statusCode == 404) {
              errorMessage = 'Ресурс не найден ${e.requestOptions.uri}';
            } else if (e.response?.statusCode == 500) {
              errorMessage = 'Ошибка сервера';
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            errorMessage = 'Превышено время ожидания';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Ошибка подключения к серверу';
          }

          throw DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
            message: errorMessage,
          );
        },
      ),
    );
  }

  static Dio get client => dio;
}

class AuthService {
  static Future<Map<String, dynamic>> sendVerificationCode(
    String email,
    String login,
  ) async {
    try {
      final response = await HttpService.client.post(
        '/auth/send-code',
        data: {'email': email, 'login': login},
      );
      final data = response.data;
      if (data['success']) {
        return {'success': true, 'message': 'Код отправлен на почту'};
      } else {
        return {'success': false, 'message': data['error']};
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? (e.message ?? 'Ошибка отправки кода')
          : 'Ошибка отправки кода';
      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<Map<String, dynamic>> verifyEmailCode(
    String email,
    String code,
  ) async {
    try {
      final response = await HttpService.client.post(
        '/auth/verify-code',
        data: {'email': email, 'code': code},
      );
      final data = response.data;
      if (data['success']) {
        return {'success': true, 'message': 'Email подтверждён'};
      } else {
        return {'success': false, 'message': data['error']};
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? (e.message ?? 'Ошибка проверки кода')
          : 'Ошибка проверки кода';
      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<Map<String, dynamic>> register(
    String login,
    String email,
    String password,
    String verificationCode,
  ) async {
    try {
      final response = await HttpService.client.post(
        '/auth/register',
        data: {
          'login': login,
          'email': email,
          'password': password,
          'code': verificationCode,
        },
      );
      final data = response.data;
      if (data['success']) {
        await _saveToken(data['token']);
        await _saveUserId(data['user']['id']);
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          NotificationService.sendTokenToServer(fcmToken);
        }
        await KeyStorageService.initializeKeys();
        return {'success': true, 'message': 'Успешная регистрация'};
      } else {
        return {'success': false, 'message': data['error']};
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? (e.message ?? 'Ошибка регистрации')
          : 'Ошибка регистрации';
      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<Map<String, dynamic>> login(
    String login,
    String password,
  ) async {
    try {
      final response = await HttpService.client.post(
        '/auth/login',
        data: {'login': login, 'password': password},
      );
      final data = response.data;
      if (data['success']) {
        await _saveToken(data['token']);
        await _saveUserId(data['user']['id']);
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          NotificationService.sendTokenToServer(fcmToken);
        }
        await KeyStorageService.initializeKeys();
        return {'success': true, 'message': 'Успешный вход'};
      } else {
        return {'success': false, 'message': data['error']};
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? (e.message ?? 'Неверные данные')
          : 'Неверные данные';
      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> _saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }
}
