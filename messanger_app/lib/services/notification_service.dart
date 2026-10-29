import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

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

    // Открытие чата по тапу на уведомление (foreground + click in background).
    _messaging.getInitialMessage().then(_handleNotificationTap);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static void _handleNotificationTap(RemoteMessage? message) {
    final chatId = message?.data['chat_id'];
    if (chatId != null) {
      log.i('Тап по уведомлению → чат $chatId');
    }
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
}
