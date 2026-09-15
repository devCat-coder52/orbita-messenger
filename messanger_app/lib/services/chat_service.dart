import 'package:dio/dio.dart';
import '../models/chat.dart';
import 'auth_service.dart';
import 'dart:io';

class ChatService {
  static Future<List<Chat>> fetchChats(String? queryString) async {
    final response = await HttpService.client.get(
      '/chat/all',
      queryParameters: {'query': queryString},
    );
    return (response.data as List).map((item) => Chat.fromJson(item)).toList();
  }

  static Future<Map<String, dynamic>> fetchMessages(
    int chatId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await HttpService.client.get(
      '/chat/$chatId/messages',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    return response.data;
  }

  static Future<Map<String, dynamic>> sendImage(
    int chatId,
    File imageFile,
    Map<String, dynamic> tempMessage,
  ) async {
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'time_create': int.parse(tempMessage['time_create']),
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'msg_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await HttpService.client.post(
      '/chat/$chatId/image',
      data: formData,
    );

    return response.data;
  }

  static Future<int> createChatWith(int userId) async {
    final response = await HttpService.client.post(
      '/chat/create',
      data: {'user_id': userId},
    );

    final chatId = response.data['chat_id'];
    return chatId;
  }

  static Future<void> togglePinChat(int chatId) async {
    await HttpService.client.post(
      '/chat/toggle-pin',
      data: {'chat_id': chatId},
    );
  }

  static Future<void> deleteChat(int chatId) async {
    await HttpService.client.post('/chat/delete', data: {'chat_id': chatId});
  }
}
