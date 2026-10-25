import 'dart:io';
import 'package:dio/dio.dart';
import '../data/chat_repository.dart';
import 'auth_service.dart';
import '../models/profile.dart';

typedef ProfileResult = ({bool success, String message});

class ProfileService {
  static Future<Profile> fetchProfile(int userId) async {
    try {
      final response = await HttpService.client.get('/profile/$userId');
      var raw = response.data;
      if (raw is Map && raw['profile'] is Map) {
        raw = raw['profile'];
      }
      final data = Map<String, dynamic>.from(raw);
      ChatRepository.cacheProfile({'id': userId, ...data}).ignore();
      return Profile.fromMap(data);
    } catch (e) {
      final cached = await ChatRepository.cachedProfile(userId);
      if (cached != null) return Profile.fromMap(cached);
      rethrow;
    }
  }

  static Future<ProfileResult> saveProfile({
    required String name,
    required String bio,
    required String location,
    required String gender,
    File? avatarFile,
    DateTime? birthDate,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('name', name));
    formData.fields.add(MapEntry('bio', bio));
    formData.fields.add(MapEntry('location', location));
    formData.fields.add(MapEntry('gender', gender));
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
    if (data['success'] == true) {
      return (success: true, message: '');
    }
    return (
      success: false,
      message: data['error']
          ? data['error'].toString()
          : 'Ошибка сохранения профиля',
    );
  }

  static Future<ProfileResult> removeAccount() async {
    final response = await HttpService.client.post('/profile/delete');
    final data = response.data;
    if (data['success'] == true) {
      return (success: true, message: '');
    }
    return (
      success: false,
      message: data['error']
          ? data['error'].toString()
          : 'Ошибка удаления аккаунта',
    );
  }
}
