import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/socket_service.dart';

import '../models/profile.dart';

import '../data/chat_repository.dart';

import 'profile/info_sections.dart';
import 'profile/info_widgets.dart';
import 'about_screen.dart';
import 'avatar_viewer_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import '../utils/image_square_crop.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  String? _loadError;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _isMyProfile = false;
  bool _showOnline = true;
  bool _showLastSeen = true;
  bool _isAvatarExpanded = false;

  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  File? _selectedImage;
  String _selectedGender = 'Не указано';
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final myId = await AuthService.getUserId();
      final profile = await ProfileService.fetchProfile(
        widget.userId,
        onCached: (cached) {
          if (!mounted) return;
          setState(() {
            _isMyProfile = widget.userId == myId;
            _applyProfile(cached);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isMyProfile = widget.userId == myId;
        _applyProfile(profile);
      });
    } catch (error) {
      if (!mounted) return;
      if (_profile != null && ChatRepository.isOfflineError(error)) {
        log.w('ProfileScreen: сервер недоступен, показан кэш: $error');
      } else {
        setState(() {
          _loadError = ChatRepository.isOfflineError(error)
              ? 'Нет соединения с сервером. Проверьте сеть и попробуйте снова.'
              : 'Не удалось загрузить профиль.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyProfile(Profile profile) {
    _profile = profile;
    _nickNameController.text = profile.nickName ?? '';
    _bioController.text = profile.bio ?? '';
    _locationController.text = profile.location ?? '';
    _selectedGender = profile.gender;
    _selectedBirthDate = profile.birthDate;
    _showOnline = profile.showOnline;
    _showLastSeen = profile.showLastSeen;
    _selectedImage = null;
    _isAvatarExpanded = false;
  }

  /// Есть ли правки, которые пропадут при выходе.
  bool get _hasUnsavedChanges {
    final profile = _profile;
    if (profile == null) return false;
    if (_selectedImage != null) return true;
    if (_nickNameController.text.trim() != (profile.nickName ?? '')) return true;
    if (_bioController.text.trim() != (profile.bio ?? '')) return true;
    if (_locationController.text.trim() != (profile.location ?? '')) {
      return true;
    }
    if (_selectedGender != profile.gender) return true;
    if (_showOnline != profile.showOnline) return true;
    if (_showLastSeen != profile.showLastSeen) return true;

    final birth = _selectedBirthDate;
    final original = profile.birthDate;
    if (birth == null && original == null) return false;
    if (birth == null || original == null) return true;
    return birth.year != original.year ||
        birth.month != original.month ||
        birth.day != original.day;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.app.error,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final name = _nickNameController.text.trim();
    if (name.isNotEmpty && name.length < 2) {
      _showError('Имя должно быть не короче 2 символов');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ProfileService.saveProfile(
        name: name,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        gender: _selectedGender,
        avatarFile: _selectedImage,
        birthDate: _selectedBirthDate,
      );

      if (!mounted) return;
      if (!result.success) {
        _showError(
          result.message.isEmpty
              ? 'Не удалось сохранить профиль'
              : result.message,
        );
        return;
      }

      // Настройки приватности сохраняются тем же нажатием «Сохранить».
      final privacySaved = await ProfileService.updatePrivacy(
        showOnline: _showOnline,
        showLastSeen: _showLastSeen,
      );
      if (!mounted) return;

      // Профиль берём с сервера: там уже правильный адрес аватара
      // и нормализованные поля.
      Profile? fresh;
      try {
        fresh = await ProfileService.fetchProfile(widget.userId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isEditMode = false;
        if (fresh != null) {
          _applyProfile(fresh);
        } else {
          // Если перечитать профиль не удалось, показываем сохранённое локально.
          final current = _profile ?? const Profile();
          final location = _locationController.text.trim();
          _applyProfile(
            Profile(
              nickName: name.isEmpty ? null : name,
              login: current.login,
              bio: _bioController.text.trim(),
              email: current.email,
              location: location.isEmpty ? null : location,
              avatarUrl: current.avatarUrl,
              birthDate: _selectedBirthDate,
              gender: _selectedGender,
            ),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            privacySaved
                ? 'Профиль сохранён'
                : 'Профиль сохранён, но приватность применить не удалось',
          ),
          backgroundColor: privacySaved
              ? context.app.success
              : context.app.warning,
        ),
      );
    } catch (error) {
      if (mounted) _showError('Ошибка сохранения профиля');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (pickedFile == null || !mounted) return;

    try {
      final cropped = await ImageSquareCrop.crop(File(pickedFile.path));
      if (!mounted) return;
      setState(() => _selectedImage = cropped);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _startEditing() => setState(() => _isEditMode = true);

  /// Тап по аватару разворачивает шапку.
  void _toggleAvatarExpanded() {
    if (_isEditMode || _profile?.avatarUrl == null) return;
    setState(() => _isAvatarExpanded = true);
  }

  /// Клик по раскрытому фото открывает полноэкранный просмотр.
  void _openAvatarViewer() {
    final url = _profile?.avatarUrl;
    if (url == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AvatarViewerScreen(imageUrl: url)),
    );
  }

  void _setPrivacy({bool? showOnline, bool? showLastSeen}) {
    setState(() {
      _showOnline = showOnline ?? _showOnline;
      _showLastSeen = showLastSeen ?? _showLastSeen;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти без сохранения?'),
        content: const Text('Изменения профиля не сохранятся.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.app.error),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _cancelEditing() async {
    if (_isSaving) return;
    if (!await _confirmDiscard()) return;
    if (!mounted) return;

    setState(() {
      _isEditMode = false;
      final profile = _profile;
      if (profile != null) _applyProfile(profile);
    });
  }

  Future<void> _exitProfile() async {
    if (_isEditMode && !await _confirmDiscard()) return;
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _logout() async {
    // Сокет закрываем до выхода: иначе сервер считает пользователя онлайн
    // до закрытия приложения.
    SocketService.disconnect();
    SocketService.clearOutbox();
    UserService().clearCache();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final app = context.app;
    return AppBar(
      title: Text(_isEditMode ? 'Редактирование профиля' : 'Профиль'),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: app.textOnHeader),
        onPressed: () => _isEditMode ? _cancelEditing() : _exitProfile(),
      ),
      actions: [
        if (_isMyProfile && !_isEditMode) ...[
          IconButton(
            icon: Icon(Icons.edit, color: app.textOnHeader),
            tooltip: 'Редактировать',
            onPressed: _startEditing,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: app.textOnHeader),
            onSelected: (value) {
              if (value == 'delete_account') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeleteAccountScreen(),
                  ),
                );
                return;
              }
              if (value == 'about') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: app.textPrimary, size: 20),
                    const SizedBox(width: 12),
                    const Text('О приложении'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: app.error, size: 20),
                    const SizedBox(width: 12),
                    Text('Удалить аккаунт', style: TextStyle(color: app.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildLoadError(context),
      );
    }

    if (widget.userId < 0) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: SingleChildScrollView(
          child: Column(
            children: [
              ProfileHeaderCard(
                profile: profile,
                isMyProfile: false,
                isEditMode: false,
                isExpanded: _isAvatarExpanded,
                selectedImage: null,
                onPickImage: _pickImage,
                isService: true,
                onAvatarTap: _toggleAvatarExpanded,
                onOpenViewer: _openAvatarViewer,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeaderCard(
              profile: profile,
              isMyProfile: _isMyProfile,
              isEditMode: _isEditMode,
              selectedImage: _selectedImage,
              onPickImage: _pickImage,
              isExpanded: _isAvatarExpanded,
              onAvatarTap: _toggleAvatarExpanded,
              onOpenViewer: _openAvatarViewer,
            ),

            const SizedBox(height: 12),

            if (!_isEditMode)
              ProfileViewSections(profile: profile)
            else ...[
              ProfileEditSections(
                nameController: _nickNameController,
                bioController: _bioController,
                locationController: _locationController,
                birthDate: _selectedBirthDate,
                gender: _selectedGender,
                onBirthDateChanged: (d) =>
                    setState(() => _selectedBirthDate = d),
                onGenderChanged: (g) => setState(() => _selectedGender = g),
              ),
              const SizedBox(height: 12),
              _PrivacySection(
                showOnline: _showOnline,
                showLastSeen: _showLastSeen,
                onShowOnlineChanged: (value) => _setPrivacy(showOnline: value),
                onShowLastSeenChanged: (value) =>
                    _setPrivacy(showLastSeen: value),
                onChangePassword: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (_isEditMode)
              _SaveBar(
                isSaving: _isSaving,
                onSave: _saveProfile,
                onCancel: _cancelEditing,
              )
            else if (_isMyProfile)
              LogoutButton(onConfirmed: _logout),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    final app = context.app;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: app.hint),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Не удалось загрузить профиль',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: app.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _initializeProfile,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nickNameController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

/// Нижняя панель с кнопками «Отмена» и «Сохранить».
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  final bool isSaving;
  final Future<void> Function() onSave;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : () => onCancel(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Отмена'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving ? null : () => onSave(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Приватность и безопасность в своём профиле.
class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.showOnline,
    required this.showLastSeen,
    required this.onShowOnlineChanged,
    required this.onShowLastSeenChanged,
    required this.onChangePassword,
  });

  final bool showOnline;
  final bool showLastSeen;
  final ValueChanged<bool> onShowOnlineChanged;
  final ValueChanged<bool> onShowLastSeenChanged;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final app = context.app;

    return Material(
      color: app.surface,
      child: Column(
        children: [
          const SectionHeader('Приватность'),
          SwitchListTile(
            title: const Text('Показывать, что я в сети'),
            value: showOnline,
            onChanged: onShowOnlineChanged,
          ),
          SwitchListTile(
            title: const Text('Показывать время последнего визита'),
            value: showLastSeen,
            onChanged: onShowLastSeenChanged,
          ),
          const SectionHeader('Безопасность'),
          ListTile(
            leading: Icon(Icons.lock_outline, color: app.textSecondary),
            title: const Text('Сменить пароль'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangePassword,
          ),
        ],
      ),
    );
  }
}
