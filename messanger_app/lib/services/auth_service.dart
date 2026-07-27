import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/logger.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.0.6:3000/api/auth';

  static Future<Map<String, dynamic>> register(
    String login,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _saveToken(data['token']);
      await _saveUserId(data['user']['id']);
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        NotificationService.sendTokenToServer(fcmToken);
      }
      return {'success': true, 'message': 'Успешная регистрация'};
    }
    final errorData = jsonDecode(response.body);
    return {
      'success': false,
      'message': errorData['error'] ?? 'Ошибка регистрации',
    };
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.0.6:3000/api',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  static Future<void> initDio() async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          log.e("Dio Error: ${e.response?.statusCode}");
          return handler.next(e);
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> login(
    String login,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['token']);
      await _saveUserId(data['user']['id']);
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        NotificationService.sendTokenToServer(fcmToken);
      }
      return {'success': true, 'message': 'Успешный вход'};
    }
    final errorData = jsonDecode(response.body);
    return {
      'success': false,
      'message': errorData['error'] ?? 'Неверные данные',
    };
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
