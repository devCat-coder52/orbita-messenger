import 'package:dio/dio.dart';
import 'dart:io';
import 'auth_service.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getProfile() async {
    final response = await HttpService.client.get('/profile');
    return response.data;
  }

  static Future<void> updateProfile({String? name, File? avatarFile}) async {
    final formData = FormData();
    if (name != null) {
      formData.fields.add(MapEntry('name', name));
    }

    if (avatarFile != null) {
      formData.files.add(
        MapEntry(
          'avatar',
          await MultipartFile.fromFile(avatarFile.path, filename: 'avatar.jpg'),
        ),
      );
    }

    final response = await HttpService.client.put('/profile', data: formData);

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }
}
