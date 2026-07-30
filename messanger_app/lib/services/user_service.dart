import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import '../models/user.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserService {
  static String baseUrl = '${dotenv.env['BASE_URL_API']}/users';

  static Future<List<User>> searchUsers(String query) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<int> createChatWith(int userId) async {
    final token = await AuthService.getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/create_chat'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final chatId = data['chat_id'];
      log.i('Created Chat ID: $chatId');
      return chatId;
    } else {
      final errorData = jsonDecode(response.body);
      log.e('Create Chat Error: $errorData');
      throw Exception(errorData['error'] ?? 'Ошибка создания чата');
    }
  }

  static Future<List<User>> getAllUsers() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/all'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<Map<String, dynamic>> getUserById(int userId) async {
    final response = await AuthService.dio.get('/users/api/users/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> getUserByChat(int chatId) async {
    final response = await AuthService.dio.get('/users/api/chats/$chatId/info');
    return response.data;
  }
}
