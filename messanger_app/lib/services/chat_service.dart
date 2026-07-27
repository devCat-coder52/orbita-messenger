import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class ChatService {
  static const String baseUrl = 'http://192.168.0.6:3000/api/chat';

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

  static Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/$chatId/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load messages');
    }
  }
}
