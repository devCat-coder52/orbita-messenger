import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import '../screens/chat_screen.dart';
import '../utils/json_utils.dart';
import '../utils/logger.dart';
import '../utils/navigation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    log.i('Push в фоне: ${message.messageId}');
  }

  static Future<void> init() async {
    String? token;
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        log.w('Пользователь отклонил запрос на уведомления');
        return;
      }

      token = await _messaging.getToken();
      FirebaseMessaging.onBackgroundMessage(backgroundHandler);
    } catch (e) {
      log.w('FCM недоступен, push-уведомления пропущены: $e');
      return;
    }

    if (token != null) {
      log.i('FCM Token получен');
      await sendTokenToServer(token);
    }

    _messaging.onTokenRefresh.listen(sendTokenToServer);

    _messaging.getInitialMessage().then(_handleNotificationTap);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static void _handleNotificationTap(RemoteMessage? message) {
    final chatId = asInt(message?.data['chat_id']);
    if (chatId == null) {
      log.w('В push нет chat_id — открыть нечего');
      return;
    }
    _openChat(chatId);
  }

  static void _openChat(int chatId, {int attempt = 0}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (attempt < 3) {
        Future<void>.delayed(
          const Duration(milliseconds: 300),
          () => _openChat(chatId, attempt: attempt + 1),
        );
      }
      return;
    }

    log.i('Тап по уведомлению → чат $chatId');
    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    navigator.push(
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
    );
  }

  static Future<void> sendTokenToServer(String token) async {
    try {
      await HttpService.client.post(
        '/users/update-fcm-token',
        data: {'fcm_token': token},
      );
    } catch (e) {
      log.e('Ошибка при отправке токена: $e');
    }
  }

  static Future<void> detachFromAccount() async {
    try {
      await HttpService.client.post(
        '/users/update-fcm-token',
        data: {'fcm_token': ''},
      );
    } catch (e) {
      log.w('Не удалось отвязать FCM-токен на сервере: $e');
    }

    try {
      await _messaging.deleteToken();
    } catch (e) {
      log.w('Не удалось удалить локальный FCM-токен: $e');
    }
  }
}
