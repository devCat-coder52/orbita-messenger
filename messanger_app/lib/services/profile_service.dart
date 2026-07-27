//import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class ProfileService {
  static const String baseUrl = 'http://192.168.0.6:3000/api/profile';

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load profile. Status Code = ${response.statusCode}',
      );
    }
  }

  static Future<void> updateProfile({String? name, File? avatarFile}) async {
    final token = await AuthService.getToken();

    final request = http.MultipartRequest('PUT', Uri.parse(baseUrl));
    request.headers['Authorization'] = 'Bearer $token';

    if (name != null) {
      request.fields['name'] = name;
    }

    if (avatarFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          avatarFile.path,
          contentType: MediaType('image', 'jpeg'), // или 'png'
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }
}
