import 'package:dio/dio.dart';
import '../models/chat.dart';
import '../models/message.dart';
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

  static Future<({List<Message> messages, bool hasMore})> fetchMessages(
    int chatId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await HttpService.client.get(
      '/chat/$chatId/messages',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = Map<String, dynamic>.from(response.data);
    return (
      messages: (data['messages'] as List)
          .map((m) => Message.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      hasMore: data['hasMore'] == true || false,
    );
  }

  static Future<Message> sendImage(
    int chatId,
    File imageFile,
    Message tempMessage,
  ) async {
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'time_create': tempMessage.timeCreate.toString(),
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'msg_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await HttpService.client.post(
      '/chat/$chatId/image',
      data: formData,
    );

    return Message.fromJson(Map<String, dynamic>.from(response.data));
  }

  static Future<Message> sendFile(
    int chatId,
    File file,
    Message tempMessage, {
    String? displayName,
  }) async {
    final fileName = displayName ?? file.path.split('/').last;

    final formData = FormData.fromMap({
      'chat_id': chatId,
      'time_create': tempMessage.timeCreate.toString(),
      'file_name': fileName,
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await HttpService.client.post(
      '/chat/$chatId/file',
      data: formData,
    );

    return Message.fromJson(Map<String, dynamic>.from(response.data));
  }

  static Future<Message> sendVoice(
    int chatId,
    File voiceFile,
    int durationSeconds,
    Message tempMessage,
  ) async {
    final ext = voiceFile.path.split('.').last;
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'time_create': tempMessage.timeCreate.toString(),
      'duration': durationSeconds,
      'voice': await MultipartFile.fromFile(
        voiceFile.path,
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext',
      ),
    });

    final response = await HttpService.client.post(
      '/chat/$chatId/voice',
      data: formData,
    );

    return Message.fromJson(Map<String, dynamic>.from(response.data));
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
