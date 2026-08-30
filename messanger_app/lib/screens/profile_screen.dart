import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../widgets/error_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isMyProfile = false;

  int? myId;
  String? _nickName;
  String _login = '';
  String? _bio;
  String? _location;
  DateTime? _birthDate;
  String? _gender;
  String? _avatarUrl;
  String? _phone;
  String? _email;
  File? _selectedImage;
  String? _selectedUrl;

  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final _defaultNickName = 'Без имени';

  String _selectedGender = 'Не указано';
  DateTime? _selectedBirthDate;
  bool _selectedFullAddress = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final myId = await AuthService.getUserId();
      _isMyProfile = widget.userId == myId;
      final data = await ProfileService.getProfile(widget.userId);
      if (data.isEmpty) throw Exception('Пользователь не найден');

      setState(() {
        _nickName = data['nick_name'];
        _login = data['login'];
        _bio = data['bio'];
        _email = data['email'];
        _location = data['location'];
        _avatarUrl = data['avatar_url'] != null
            ? '${dotenv.env['BASE_URL']}/${data['avatar_url']}'
            : null;

        var birthDateData = data['birth_date'];
        if (birthDateData is Timestamp) {
          _birthDate = birthDateData.toDate();
        } else if (birthDateData is String) {
          _birthDate = DateTime.tryParse(birthDateData);
        }

        _gender = data['gender'] ?? 'Не указано';

        _nickNameController.text = _nickName ?? '';
        _locationController.text = _location ?? '';
        _selectedFullAddress = _location != null;
        _bioController.text = _bio ?? '';
        _selectedGender = _gender!;
        _selectedBirthDate = _birthDate;
      });
    } catch (error) {
      if (!mounted) return;
      ErrorDialog.show(context, 'LoginScreen: Ошибка входа: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final updateResult = await ProfileService.updateProfile(
        name: _nickNameController.text,
        avatarFile: _selectedImage,
        bio: _bioController.text,
        birthDate: _selectedBirthDate,
        location: _selectedFullAddress ? _locationController.text : '',
        gender: _selectedGender,
      );

      if (!updateResult["success"]) {
        _showError(updateResult['message']);
        return;
      }

      setState(() {
        _isEditMode = false;
        _nickName = _nickNameController.text.isNotEmpty
            ? _nickNameController.text
            : null;
        _bio = _bioController.text;
        _birthDate = _selectedBirthDate;
        _location = _locationController.text;
        _gender = _selectedGender;
        _avatarUrl = _selectedUrl ?? _avatarUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль успешно сохранен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка сохранения профиля'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.grey.shade600),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedUrl = pickedFile.path;
      });
    }
  }

  void _pickGender() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Выберите пол',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...['Мужской', 'Женский', 'Не указано'].map(
              (g) => ListTile(
                title: Text(g),
                onTap: () {
                  setState(() => _selectedGender = g);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    UserService().clearCache();
    SocketService.disconnect();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    IconData? icon,
    bool isEditable = false,
    VoidCallback? onTap,
    Widget? editWidget,
  }) {
    final displayValue = value?.isEmpty ?? true ? 'Не указано' : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: isEditable
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable && !_isEditMode && onTap != null)
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          if (_isEditMode && editWidget != null) editWidget,
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildAutoCompleteField(
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Autocomplete(
        initialValue: TextEditingValue(text: _locationController.text),
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Местоположение',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _locationController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            _selectedFullAddress
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _selectedFullAddress
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                          onPressed: () {
                            _locationController.clear();
                            setState(() {
                              _selectedFullAddress = false;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedFullAddress = false;
                  });
                },
              );
            },
        optionsBuilder: (textEditingValue) async {
          if (textEditingValue.text.isEmpty && !_selectedFullAddress) {
            return const Iterable<String>.empty();
          }
          final cities = await LocationService().searchCities(
            textEditingValue.text,
          );
          return cities.map((c) => c.value);
        },
        displayStringForOption: (option) => option,
        onSelected: (selection) {
          setState(() {
            _locationController.text = selection;
            _selectedFullAddress = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Профиль'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _isEditMode == true
              ? setState(() {
                  _isEditMode = false;
                })
              : Navigator.pop(context),
        ),
        actions: [
          if (_isMyProfile)
            _isEditMode
                ? IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    onPressed: _saveProfile,
                  )
                : IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => setState(() => _isEditMode = true),
                  ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: (_avatarUrl == null && _selectedUrl == null)
                            ? Text(
                                _nickName!.isNotEmpty
                                    ? _nickName![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      if (_isMyProfile && _isEditMode)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isEditMode)
                    TextField(
                      controller: _nickNameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  else
                    Text(
                      _nickName ?? _defaultNickName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '@$_login',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Основная информация
            if (!_isEditMode) ...[
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader('Основное'),
                    _buildInfoRow('О себе', _bio, icon: Icons.info_outline),
                    _buildInfoRow(
                      'Местоположение',
                      _location,
                      icon: Icons.location_on_outlined,
                    ),
                    _buildInfoRow(
                      'Дата рождения',
                      _birthDate != null
                          ? DateFormat(
                              'dd MMMM yyyy',
                              'ru_RU',
                            ).format(_birthDate!)
                          : null,
                      icon: Icons.cake_outlined,
                    ),
                    _buildInfoRow('Пол', _gender, icon: Icons.person_outline),

                    _buildSectionHeader('Контакты'),
                    _buildInfoRow('Email', _email, icon: Icons.email_outlined),
                    _buildInfoRow(
                      'Телефон',
                      _phone,
                      icon: Icons.phone_outlined,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    _buildEditableField(
                      'О себе',
                      _bioController,
                      icon: Icons.info_outline,
                    ),
                    _buildAutoCompleteField(
                      'Местоположение',
                      _locationController,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cake_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Дата рождения',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _selectedBirthDate != null
                                      ? DateFormat(
                                          'dd.MM.yyyy',
                                        ).format(_selectedBirthDate!)
                                      : 'Не указана',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _pickDate,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: Colors.grey,
                      ),
                      title: const Text('Пол'),
                      subtitle: Text(_selectedGender),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickGender,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (_isMyProfile && !_isEditMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Выход'),
                          content: const Text(
                            'Вы действительно хотите выйти из аккаунта?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Отмена'),
                            ),
                            ElevatedButton(
                              onPressed: _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Выйти'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

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
