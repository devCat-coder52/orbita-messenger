import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/auth_service.dart';
import '../utils/logger.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static Future<void> connectIfNotConnected() async {
    if (_socket != null && _socket!.connected) return;

    final token = await AuthService.getToken();
    _socket = IO.io('http://192.168.0.6:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'extraHeaders': {'Authorization': 'Bearer $token'},
    });

    _socket!.onConnect((_) => log.i('Socket connected'));
    _socket!.onDisconnect((_) => log.i('Socket disconnected'));

    // ВАЖНО: При подключении сразу сообщаем серверу, что мы онлайн
    _socket!.onConnect((_) async {
      final userId = await AuthService.getUserId();
      if (userId != null) {
        _socket?.emit('user_connected', userId);
      }
    });
  }

  // Методы для событий
  static void emit(String event, [dynamic data]) => _socket?.emit(event, data);
  static void on(String event, Function(dynamic) callback) =>
      _socket?.on(event, callback);
  static void off(String event, [Function(dynamic)? callback]) =>
      _socket?.off(event, callback);

  // Утилитарные методы
  static void joinChat(int chatId) => emit('join_chat', chatId);
  static void markAsRead(int chatId, int userId) =>
      emit('mark_as_read', {'chat_id': chatId, 'user_id': userId});
  static Future<void> sendMessage(
    String content,
    int chatId,
    String userName,
    String createdAt,
  ) async {
    if (_socket == null || !_socket!.connected) {
      throw Exception('Нет соединения с сервером');
    }

    try {
      _socket?.emit('send_message', {
        'content': content,
        'chat_id': chatId,
        'user_name': userName,
        'created_at': createdAt,
      });
    } catch (e) {
      log.i('Ошибка отправки сообщения через сокет: $e');
      rethrow;
    }
  }

  // --- Слушатели
  static void onReceiveMessage(Function(dynamic) callback) =>
      _socket?.on('receive_message', callback);
  static void offReceiveMessage(Function(dynamic) callback) =>
      _socket?.off('receive_message', callback);

  static void onMessageStatusUpdated(Function(dynamic) callback) =>
      _socket?.on('message_status_updated', callback);
  static void offMessageStatusUpdated(Function(dynamic) callback) =>
      _socket?.off('message_status_updated', callback);

  static void onUserStatusChanged(Function(dynamic) callback) =>
      _socket?.on('user_status_changed', callback);
  static void offUserStatusChanged(Function(dynamic) callback) =>
      _socket?.off('user_status_changed', callback);

  static void disconnect() {
    _socket?.disconnect();
  }
}
