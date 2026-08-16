import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static Future<void> connectIfNotConnected() async {
    if (_socket != null && _socket!.connected) return;

    final token = await AuthService.getToken();
    _socket = IO.io(dotenv.env['BASE_URL'], <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'extraHeaders': {'Authorization': 'Bearer $token'},
    });

    _socket!.onConnect((_) => log.i('Socket connected'));
    _socket!.onDisconnect((_) => log.i('Socket disconnected'));

    _socket!.onConnect((_) async {
      final userId = await AuthService.getUserId();
      if (userId != null) {
        _socket?.emit('user_connected', userId);
      }
    });
  }

  static void emit(String event, [dynamic data]) => _socket?.emit(event, data);
  static void on(String event, Function(dynamic) callback) =>
      _socket?.on(event, callback);
  static void off(String event, [Function(dynamic)? callback]) =>
      _socket?.off(event, callback);
  static void joinChat(int chatId) => emit('join_chat', chatId);
  static void leaveChat(int chatId) => emit('leave_chat', chatId);
  static void markAsRead(int chatId, int userId) =>
      emit('mark_as_read', {'chat_id': chatId, 'user_id': userId});
  static void sendTypingStatus(int chatId, String userName, bool isTyping) =>
      emit('typing', {
        'chat_id': chatId,
        'user_name': userName,
        'is_typing': isTyping,
      });

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

  static Future<void> editMessage(int messageId, String content) async {
    if (_socket == null || !_socket!.connected) {
      throw Exception('Нет соединения с сервером');
    }
    _socket?.emit('edit_message', {
      'message_id': messageId,
      'content': content,
    });
  }

  static Future<void> deleteMessage(
    int messageId,
    int chatId,
    int? userId,
  ) async {
    if (_socket == null || !_socket!.connected) {
      throw Exception('Нет соединения с сервером');
    }
    _socket?.emit('delete_message', {
      'message_id': messageId,
      'chat_id': chatId,
      'user_id': userId,
    });
  }

  static void onReceiveMessage(Function(dynamic) callback) =>
      _socket?.on('receive_message', callback);
  static void offReceiveMessage([Function(dynamic)? callback]) =>
      _socket?.off('receive_message', callback);

  static void onMessageEdited(Function(dynamic) callback) =>
      _socket?.on('message_edited', callback);
  static void offMessageEdited([Function(dynamic)? callback]) =>
      _socket?.off('message_edited', callback);

  static void onMessageDeleted(Function(dynamic) callback) =>
      _socket?.on('message_deleted', callback);
  static void offMessageDeleted([Function(dynamic)? callback]) =>
      _socket?.off('message_deleted', callback);

  static void onMessageStatusUpdated(Function(dynamic) callback) =>
      _socket?.on('message_status_updated', callback);
  static void offMessageStatusUpdated([Function(dynamic)? callback]) =>
      _socket?.off('message_status_updated', callback);

  static void onUserStatusChanged(Function(dynamic) callback) =>
      _socket?.on('user_status_changed', callback);
  static void offUserStatusChanged([Function(dynamic)? callback]) =>
      _socket?.off('user_status_changed', callback);

  static void onUserTyping(Function(dynamic) callback) =>
      _socket?.on('user_typing', callback);
  static void offUserTyping([Function(dynamic)? callback]) =>
      _socket?.off('user_typing', callback);

  static void disconnect() {
    _socket?.disconnect();
  }
}
