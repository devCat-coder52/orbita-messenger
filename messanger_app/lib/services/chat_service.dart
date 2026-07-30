import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static String baseUrl = '${dotenv.env['BASE_URL_API']}/chat';

  static Future<List<Map<String, dynamic>>> fetchChats() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chats');
    }
  }

  static Future<Map<String, dynamic>> fetchMessages(
    int chatId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await AuthService.dio.get(
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

    final response = await AuthService.dio.post(
      '/chat/$chatId/image',
      data: formData,
    );

    return response.data;
  }
}
