import 'package:dio/dio.dart';
import 'dart:io';
import 'auth_service.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getProfile(int? userId) async {
    final response = await HttpService.client.get('/profile/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? gender,
    File? avatarFile,
    String? bio,
    DateTime? birthDate,
    String? location,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('name', name!));
    formData.fields.add(MapEntry('bio', bio!));
    formData.fields.add(MapEntry('location', location!));
    formData.fields.add(MapEntry('gender', gender!));
    if (avatarFile != null) {
      formData.files.add(
        MapEntry(
          'avatar',
          await MultipartFile.fromFile(avatarFile.path, filename: 'avatar.jpg'),
        ),
      );
    }
    if (birthDate != null) {
      formData.fields.add(
        MapEntry('birth_date', birthDate.toIso8601String().split('T').first),
      );
    }

    final response = await HttpService.client.put('/profile', data: formData);
    final data = response.data;
    if (data['success']) {
      return {'success': true};
    } else {
      return {'success': false, 'message': data['error']};
    }
  }
}
