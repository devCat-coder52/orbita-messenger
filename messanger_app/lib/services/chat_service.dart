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
    return (response.data as List)
        .map((item) => Chat.fromJson(item))
        .toList(); //List<Chat>.from(response.data);
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
      'created_at': tempMessage['created_at'],
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
}
