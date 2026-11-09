import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_repository.dart';
import 'auth_service.dart';
import '../models/profile.dart';

typedef ProfileResult = ({bool success, String message});

class ProfileService {
  static Future<Profile> fetchProfile(
    int userId, {
    void Function(Profile cached)? onCached,
  }) async {
    Map<String, dynamic>? cached;
    try {
      cached = await ChatRepository.cachedProfile(userId);
    } catch (_) {}

    final cachedProfile = cached != null ? Profile.fromMap(cached) : null;
    if (cachedProfile != null && onCached != null) {
      onCached(cachedProfile);
    }
    try {
      final response = await HttpService.client.get('/profile/$userId');
      var raw = response.data;
      if (raw is Map && raw['profile'] is Map) {
        raw = raw['profile'];
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['email'] == null) {
        final myId = await AuthService.getUserId();
        if (myId == userId) {
          final prefs = await SharedPreferences.getInstance();
          final savedEmail = prefs.getString('user_email');
          if (savedEmail != null && savedEmail.isNotEmpty) {
            data['email'] = savedEmail;
          }
        }
      }
      ChatRepository.cacheProfile({'id': userId, ...data}).ignore();
      return Profile.fromMap(data);
    } catch (e) {
      if (cachedProfile != null && ChatRepository.isOfflineError(e)) {
        return cachedProfile;
      }
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
      // Сохраняем исходное расширение: сервер отдаёт Content-Type по нему.
      final rawExtension = avatarFile.path.split('.').last.toLowerCase();
      final extension =
          const {'jpg', 'jpeg', 'png', 'webp'}.contains(rawExtension)
          ? rawExtension
          : 'jpg';
      formData.files.add(
        MapEntry(
          'avatar',
          await MultipartFile.fromFile(
            avatarFile.path,
            filename: 'avatar.$extension',
          ),
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

  /// Смена пароля. Сервер возвращает новый токен для текущего устройства.
  /// Отправляет код подтверждения на email текущего пользователя.
  static Future<({bool success, String message})>
  requestPasswordChangeCode() async {
    try {
      final response = await HttpService.client.post('/profile/password-code');
      final data = Map<String, dynamic>.from(response.data as Map);
      return (
        success: data['success'] == true,
        message: (data['error'] ?? '').toString(),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? (data['error'] ?? '').toString() : '';
      return (
        success: false,
        message: message.isEmpty ? 'Не удалось отправить код' : message,
      );
    } catch (_) {
      return (success: false, message: 'Не удалось отправить код');
    }
  }

  static Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
    required String code,
  }) async {
    try {
      final response = await HttpService.client.post(
        '/profile/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'code': code,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token'] as String?;
      if (data['success'] == true && token != null) {
        await AuthService.updateToken(token);
      }
      return (
        success: data['success'] == true,
        message: (data['error'] ?? '').toString(),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? (data['error'] ?? '').toString() : '';
      return (
        success: false,
        message: message.isEmpty ? 'Не удалось сменить пароль' : message,
      );
    } catch (_) {
      return (success: false, message: 'Не удалось сменить пароль');
    }
  }

  /// Приватность: показывать ли «в сети» и «был(а) недавно».
  static Future<bool> updatePrivacy({
    required bool showOnline,
    required bool showLastSeen,
  }) async {
    try {
      final response = await HttpService.client.post(
        '/profile/privacy',
        data: {'show_online': showOnline, 'show_last_seen': showLastSeen},
      );
      return response.data is Map && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<({bool success, String message})>
  requestDeleteAccountCode() async {
    try {
      final response = await HttpService.client.post('/profile/delete-code');
      final data = Map<String, dynamic>.from(response.data as Map);
      return (
        success: data['success'] == true,
        message: (data['error'] ?? '').toString(),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? (data['error'] ?? '').toString() : '';
      return (
        success: false,
        message: message.isEmpty ? 'Не удалось отправить код' : message,
      );
    } catch (_) {
      return (success: false, message: 'Не удалось отправить код');
    }
  }

  static Future<ProfileResult> removeAccount({
    required String password,
    required String code,
  }) async {
    try {
      final response = await HttpService.client.post(
        '/profile/delete',
        data: {'password': password, 'code': code},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] == true) {
        return (success: true, message: '');
      }
      return (
        success: false,
        message: (data['error'] ?? '').toString().isEmpty
            ? 'Ошибка удаления аккаунта'
            : data['error'].toString(),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? (data['error'] ?? '').toString() : '';
      return (
        success: false,
        message: message.isEmpty ? 'Ошибка удаления аккаунта' : message,
      );
    } catch (_) {
      return (success: false, message: 'Ошибка удаления аккаунта');
    }
  }
}
