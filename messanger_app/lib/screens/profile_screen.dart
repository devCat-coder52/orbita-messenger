import 'dart:io';

//import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
//import '../services/location_service.dart';

import '../models/profile.dart';

import '../widgets/error_dialog.dart';
import '../data/chat_repository.dart';

import 'profile/info_sections.dart';
import 'profile/info_widgets.dart';
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

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isMyProfile = false;

  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  File? _selectedImage;
  String? _selectedUrl;
  String _selectedGender = 'Не указано';
  DateTime? _selectedBirthDate;
  bool _selectedFullAddress = false;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    setState(() => _isLoading = true);
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
        ErrorDialog.show(
          context,
          'ProfileScreen: Ошибка загрузки профиля: $error',
        );
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
    _selectedFullAddress = profile.location != null;
    _selectedGender = profile.gender;
    _selectedBirthDate = profile.birthDate;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ProfileService.saveProfile(
        name: _nickNameController.text,
        bio: _bioController.text,
        location: _selectedFullAddress ? _locationController.text : '',
        gender: _selectedGender,
        avatarFile: _selectedImage,
        birthDate: _selectedBirthDate,
      );

      if (!result.success) {
        _showError(result.message);
        return;
      }

      final current = _profile ?? const Profile();

      setState(() {
        _isEditMode = false;
        _profile = Profile(
          nickName: _nickNameController.text.isNotEmpty
              ? _nickNameController.text
              : null,
          login: current.login,
          bio: _bioController.text,
          email: current.email,
          phone: current.phone,
          location: _selectedFullAddress ? _locationController.text : null,
          avatarUrl: _selectedUrl ?? current.avatarUrl,
          birthDate: _selectedBirthDate,
          gender: _selectedGender,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Профиль успешно сохранен'),
            backgroundColor: AppTokens.of(context).success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения профиля'),
            backgroundColor: AppTokens.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedUrl = pickedFile.path;
      });
    }
  }

  void _logout() async {
    UserService().clearCache();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteAccount() async {
    if (!await confirmDeleteAccount(context)) return;

    setState(() => _isLoading = true);
    try {
      final result = await ProfileService.removeAccount();
      if (result.success) {
        UserService().clearCache();
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showError(
          result.message.isEmpty ? 'Ошибка удаления аккаунта' : result.message,
        );
      }
      null;
    } catch (error) {
      _showError('Ошибка удаления аккаунта: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final app = context.app;
    return AppBar(
      title: const Text('Профиль'),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: app.textOnHeader),
        onPressed: () => _isEditMode
            ? setState(() => _isEditMode = false)
            : Navigator.pop(context),
      ),
      actions: [
        if (_isMyProfile) ...[
          IconButton(
            icon: Icon(
              _isEditMode ? Icons.save : Icons.edit,
              color: app.textOnHeader,
            ),
            onPressed: () {
              if (_isEditMode) {
                _saveProfile();
              } else {
                setState(() => _isEditMode = true);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: app.textOnHeader),
            onSelected: (_) => _deleteAccount(),
            itemBuilder: (context) => [
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
    if (_isLoading || _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile!;

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
              selectedUrl: _selectedUrl,
              nickNameController: _nickNameController,
              onPickImage: _pickImage,
            ),

            const SizedBox(height: 12),

            if (!_isEditMode)
              ProfileViewSections(profile: profile)
            else
              ProfileEditSections(
                bioController: _bioController,
                locationController: _locationController,
                birthDate: _selectedBirthDate,
                gender: _selectedGender,
                fullAddressSelected: _selectedFullAddress,
                onBirthDateChanged: (d) =>
                    setState(() => _selectedBirthDate = d),
                onGenderChanged: (g) => setState(() => _selectedGender = g),
                onFullAddressChanged: (v) =>
                    setState(() => _selectedFullAddress = v),
              ),

            const SizedBox(height: 20),

            if (_isMyProfile && !_isEditMode)
              LogoutButton(onConfirmed: _logout),

            const SizedBox(height: 30),
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
