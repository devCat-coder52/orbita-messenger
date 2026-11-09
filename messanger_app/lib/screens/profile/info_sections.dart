import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import 'info_widgets.dart';

class ProfileHeaderCard extends StatelessWidget {
  final Profile profile;
  final bool isMyProfile;
  final bool isEditMode;
  final bool isExpanded;
  final File? selectedImage;
  final VoidCallback onPickImage;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onOpenViewer;

  /// Сервисный аккаунт: вместо логина показываем «администратор».
  final bool isService;

  const ProfileHeaderCard({
    required this.profile,
    required this.isMyProfile,
    required this.isEditMode,
    required this.isExpanded,
    required this.selectedImage,
    required this.onPickImage,
    this.onAvatarTap,
    this.onOpenViewer,
    this.isService = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final showExpanded = isExpanded && !isEditMode && profile.avatarUrl != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: showExpanded ? _expanded(context, app) : _collapsed(context, app),
    );
  }

  /// Развёрнутый вид: фото на всю шапку, имя и логин поверх него.
  Widget _expanded(BuildContext context, AppTokens app) {
    return GestureDetector(
      onTap: onOpenViewer,
      child: Container(
        width: double.infinity,
        height: 340,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: profile.avatarUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              maxWidthDiskCache: 1600,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.5, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.nickName ?? 'Без имени',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isService ? 'администратор' : '@${profile.login}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapsed(BuildContext context, AppTokens app) {
    return Container(
      width: double.infinity,
      color: app.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: isEditMode ? null : onAvatarTap,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: app.surfaceVariant,
                  backgroundImage: selectedImage != null
                      ? FileImage(selectedImage!)
                      : profile.avatarUrl != null
                      ? CachedNetworkImageProvider(
                          profile.avatarUrl!,
                          maxWidth: 120,
                          maxHeight: 120,
                        )
                      : null,
                  child: profile.avatarUrl == null && selectedImage == null
                      ? Text(
                          profile.nickName != null
                              ? profile.nickName![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 40,
                            color: app.textOnAccent,
                          ),
                        )
                      : null,
                ),
              ),
              if (isMyProfile && isEditMode)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Tooltip(
                    message: 'Изменить фото',
                    child: InkResponse(
                      onTap: onPickImage,
                      radius: 22,
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: app.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: app.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 17,
                          color: app.textOnAccent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.nickName ?? 'Без имени',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: app.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _LoginChip(login: profile.login, isService: isService),
        ],
      ),
    );
  }
}

class _LoginChip extends StatelessWidget {
  const _LoginChip({required this.login, this.isService = false});

  final String login;
  final bool isService;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '@$login'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Логин @$login скопирован'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;

    if (isService) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: app.surfaceVariant,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 14,
              color: Color(0xFFFF8F00),
            ),
            const SizedBox(width: 6),
            const Text(
              'администратор',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF8F00),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => _copy(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: app.surfaceVariant,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@$login',
              style: TextStyle(fontSize: 13, color: app.textSecondary),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 13, color: app.hint),
          ],
        ),
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
        ],
      ),
    );
  }
}

class ProfileEditSections extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final DateTime? birthDate;
  final String gender;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<String> onGenderChanged;

  const ProfileEditSections({
    required this.nameController,
    required this.bioController,
    required this.locationController,
    required this.birthDate,
    required this.gender,
    required this.onBirthDateChanged,
    required this.onGenderChanged,
    super.key,
  });

  @override
  State<ProfileEditSections> createState() => _ProfileEditSectionsState();
}

class _ProfileEditSectionsState extends State<ProfileEditSections> {
  static const _genders = ['Мужской', 'Женский', 'Не указано'];

  String? _nameError;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_validateName);
  }

  void _validateName() {
    final length = widget.nameController.text.trim().length;
    final error = length > 0 && length < 2 ? 'Минимум 2 символа' : null;
    if (error != _nameError) setState(() => _nameError = error);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_validateName);
    super.dispose();
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.nameController,
              builder: (context, value, _) {
                final length = value.text.runes.length;

                return Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: widget.nameController,
                      maxLength: 25,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(fontSize: 16, color: app.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Имя',
                        hintText: 'Как вас видят в чатах',
                        errorText: _nameError,
                        counterText: '',
                        prefixIcon: const Icon(Icons.person_outline),
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          68,
                          16,
                        ),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: app.surfaceVariant,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: IgnorePointer(
                        child: Text(
                          '$length/25',
                          style: TextStyle(
                            fontSize: 12,
                            color: length >= 25
                                ? app.error
                                : app.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          EditableField(
            label: 'О себе',
            controller: widget.bioController,
            icon: Icons.info_outline,
            maxLength: 100,
            maxLines: 3,
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
                      decoration: const InputDecoration(
                        labelText: 'Город',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      // Текст всегда синхронизируется с общим контроллером:
                      // раньше город, введённый вручную без выбора подсказки,
                      // при сохранении уходил пустым.
                      onChanged: (value) =>
                          widget.locationController.text = value,
                    );
                  },
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                final cities = await LocationService().searchCities(
                  textEditingValue.text,
                );
                return cities.map((c) => c.value);
              },
              displayStringForOption: (option) => option,
              onSelected: (selection) =>
                  widget.locationController.text = selection,
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
                  tooltip: 'Выбрать дату',
                  onPressed: _pickDate,
                  color: app.textSecondary,
                ),
              ],
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              leading: Icon(Icons.person_outline, color: app.textSecondary),
              title: const Text('Пол'),
              subtitle: Text(widget.gender),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickGender,
            ),
          ),
        ],
      ),
    );
  }
}

