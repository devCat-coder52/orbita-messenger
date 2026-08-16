import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/profile_service.dart';
import '../widgets/error_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String? name;
  String? avatarUrl;
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      setState(() {
        name = profile['name'];
        avatarUrl = '${dotenv.env['BASE_URL']}/${profile['avatar_url']}';
        _nameController.text = name ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'ProfileScreen: Ошибка загрузки профиля: $e');
    }
  }

  void _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _saveProfile() async {
    try {
      await ProfileService.updateProfile(
        name: _nameController.text,
        avatarFile: _selectedImage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Профиль обновлён')));
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'ProfileScreen: Ошибка сохранения профиля: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Настройки профиля')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF3498DB),
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: _selectedImage == null && avatarUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Имя'),
            ),
            SizedBox(height: 24),
            ElevatedButton(onPressed: _saveProfile, child: Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
