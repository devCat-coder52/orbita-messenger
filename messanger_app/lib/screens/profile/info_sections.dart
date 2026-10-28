import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/profile.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
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
    final app = context.app;
    return Container(
      width: double.infinity,
      color: app.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: app.surfaceVariant,
                backgroundImage: selectedImage != null
                    ? FileImage(selectedImage!)
                    : profile.avatarUrl != null
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : null,
                child: (profile.avatarUrl == null && selectedUrl == null)
                    ? Text(
                        profile.nickName != null
                            ? profile.nickName![0].toUpperCase()
                            : '?',
                        style: TextStyle(fontSize: 40, color: app.textOnAccent),
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
                        color: app.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: app.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: app.textOnAccent,
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: app.textPrimary,
              ),
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.zero,
              ),
            )
          else
            Text(
              profile.nickName ?? 'Без имени',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: app.textPrimary,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '@${profile.login}',
            style: TextStyle(fontSize: 14, color: app.textSecondary),
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
      color: context.app.surface,
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
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: context.app.secondary),
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
    final app = context.app;
    return Container(
      color: app.surface,
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
                                      ? app.success
                                      : app.error,
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
                Icon(Icons.cake_outlined, size: 20, color: app.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дата рождения',
                        style: TextStyle(
                          fontSize: 12,
                          color: app.textSecondary,
                        ),
                      ),
                      Text(
                        widget.birthDate != null
                            ? DateFormat('dd.MM.yyyy').format(widget.birthDate!)
                            : 'Не указана',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.birthDate != null
                              ? app.textPrimary
                              : app.hint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                  color: app.textSecondary,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.person_outline, color: app.textSecondary),
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
          style: TextButton.styleFrom(foregroundColor: context.app.error),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
