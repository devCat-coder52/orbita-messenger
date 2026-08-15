import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class UserService {
  static String baseUrl = '/users';

  static Future<List<User>> searchUsers(String query) async {
    final response = await HttpService.client.get(
      '$baseUrl/search',
      queryParameters: {'q': query},
    );
    final List<dynamic> data = response.data;
    return data.map((json) => User.fromJson(json)).toList();
  }

  static Future<int> createChatWith(int userId) async {
    final response = await HttpService.client.post(
      '$baseUrl/create_chat',
      data: {'user_id': userId},
    );

    final chatId = response.data['chat_id'];
    log.i('Created Chat ID: $chatId');
    return chatId;
  }

  static Future<List<User>> getAllUsers() async {
    final response = await HttpService.client.get('$baseUrl/all');
    final List<dynamic> data = response.data;
    return data.map((json) => User.fromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> getUserById(int userId) async {
    final response = await HttpService.client.get('$baseUrl/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> getUserByChat(int chatId) async {
    final response = await HttpService.client.get('/chats/$chatId/info');
    return response.data;
  }
}
