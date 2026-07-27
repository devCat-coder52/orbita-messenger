// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
//import 'package:dio/dio.dart';
import '../utils/logger.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Получаем токен
      /*String? token = await _messaging.getToken();

      if (token != null) {
        print("FCM Token: $token");
        await _sendTokenToServer(token);
      } else {
        print("Токен пока равен null, ждем обновления...");
      }*/
    } else {
      log.w('Пользователь отклонил запрос на уведомления');
    }

    // 3. Слушаем изменения токена (если Firebase его обновит)
    _messaging.onTokenRefresh.listen((newToken) {
      //_sendTokenToServer(newToken);
    });
  }

  /*static Future<void> _sendTokenToServer(String token) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        log.e('Не удалось получить userId для отправки токена!');
        return;
      }

      // Используем Dio или http для отправки
      final dio = Dio(BaseOptions(baseUrl: 'http://192.168.0.6:3000/api'));

      await dio.post(
        '/users/update-fcm-token',
        data: {'user_id': userId, 'fcm_token': token},
      );
    } catch (e) {
      log.e('Ошибка при отправке токена: $e');
    }
  }*/

  static Future<void> sendTokenToServer(String token) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        log.e('Не удалось получить userId для отправки токена');
        return;
      }
      await AuthService.dio.post(
        '/users/update-fcm-token',
        data: {'user_id': userId, 'fcm_token': token},
      );
    } catch (e) {
      log.e('Ошибка при отправке токена: $e');
    }
  }
}
