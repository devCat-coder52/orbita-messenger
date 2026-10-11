import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../services/location_service.dart';
import 'info_widgets.dart';

class ProfileHeaderCard extends StatelessWidget {
  final Profile profile;
  final bool isMyProfile;
  final bool isEditMode;
  final File? selectedImage;
  final String? selectedUrl;
  final TextEditingController nickNameController;
  final VoidCallback onPickImage;

  const ProfileHeaderCard({
    required this.profile,
    required this.isMyProfile,
    required this.isEditMode,
    required this.selectedImage,
    required this.selectedUrl,
    required this.nickNameController,
    required this.onPickImage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                backgroundImage: selectedImage != null
                    ? FileImage(selectedImage!)
                    : profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: (profile.avatarUrl == null && selectedUrl == null)
                    ? Text(
                        profile.nickName != null
                            ? profile.nickName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              if (isMyProfile && isEditMode)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onPickImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
          if (isEditMode)
            TextField(
              controller: nickNameController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.zero,
              ),
            )
          else
            Text(
              profile.nickName ?? 'Без имени',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            '@${profile.login}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class ProfileViewSections extends StatelessWidget {
  final Profile profile;
  const ProfileViewSections({required this.profile, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SectionHeader('Основное'),
          InfoRow(
            label: 'О себе',
            value: profile.bio,
            icon: Icons.info_outline,
          ),
          InfoRow(
            label: 'Местоположение',
            value: profile.location,
            icon: Icons.location_on_outlined,
          ),
          InfoRow(
            label: 'Дата рождения',
            value: profile.birthDate != null
                ? DateFormat('dd MMMM yyyy', 'ru_RU').format(profile.birthDate!)
                : null,
            icon: Icons.cake_outlined,
          ),
          InfoRow(
            label: 'Пол',
            value: profile.gender,
            icon: Icons.person_outline,
          ),
          const SectionHeader('Контакты'),
          InfoRow(
            label: 'Email',
            value: profile.email,
            icon: Icons.email_outlined,
          ),
          InfoRow(
            label: 'Телефон',
            value: profile.phone,
            icon: Icons.phone_outlined,
          ),
        ],
      ),
    );
  }
}

class ProfileEditSections extends StatefulWidget {
  final TextEditingController bioController;
  final TextEditingController locationController;
  final DateTime? birthDate;
  final String gender;
  final bool fullAddressSelected;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<bool> onFullAddressChanged;

  const ProfileEditSections({
    required this.bioController,
    required this.locationController,
    required this.birthDate,
    required this.gender,
    required this.fullAddressSelected,
    required this.onBirthDateChanged,
    required this.onGenderChanged,
    required this.onFullAddressChanged,
    super.key,
  });

  @override
  State<ProfileEditSections> createState() => _ProfileEditSectionsState();
}

class _ProfileEditSectionsState extends State<ProfileEditSections> {
  static const _genders = ['Мужской', 'Женский', 'Не указано'];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.birthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.grey.shade600),
        ),
        child: child!,
      ),
    );
    if (picked != null) widget.onBirthDateChanged(picked);
  }

  void _pickGender() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
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
            ..._genders.map(
              (g) => ListTile(
                title: Text(g),
                onTap: () {
                  widget.onGenderChanged(g);
                  Navigator.pop(sheetContext);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          EditableField(
            label: 'О себе',
            controller: widget.bioController,
            icon: Icons.info_outline,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Autocomplete<String>(
              initialValue: TextEditingValue(
                text: widget.locationController.text,
              ),
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Местоположение',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: widget.locationController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  widget.fullAddressSelected
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: widget.fullAddressSelected
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                                onPressed: () {
                                  widget.locationController.clear();
                                  widget.onFullAddressChanged(false);
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => widget.onFullAddressChanged(false),
                    );
                  },
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty &&
                    !widget.fullAddressSelected) {
                  return const Iterable<String>.empty();
                }
                final cities = await LocationService().searchCities(
                  textEditingValue.text,
                );
                return cities.map((c) => c.value);
              },
              displayStringForOption: (option) => option,
              onSelected: (selection) {
                widget.locationController.text = selection;
                widget.onFullAddressChanged(true);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Дата рождения',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        widget.birthDate != null
                            ? DateFormat('dd.MM.yyyy').format(widget.birthDate!)
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
            leading: const Icon(Icons.person_outline, color: Colors.grey),
            title: const Text('Пол'),
            subtitle: Text(widget.gender),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickGender,
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удаление аккаунта'),
      content: const Text(
        'Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить. Все ваши данные будут безвозвратно удалены.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
