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
      String? token = await _messaging.getToken();
      if (token != null) {
        log.i("FCM Token: $token");
        await sendTokenToServer(token);
      }
    } else {
      log.w('Пользователь отклонил запрос на уведомления');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      sendTokenToServer(newToken);
    });
  }

  static Future<void> sendTokenToServer(String token) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        log.e('Не удалось получить userId для отправки токена');
        return;
      }
      await HttpService.client.post(
        '/users/update-fcm-token',
        data: {'user_id': userId, 'fcm_token': token},
      );
    } catch (e) {
      log.e('Ошибка при отправке токена: $e');
    }
  }
}
