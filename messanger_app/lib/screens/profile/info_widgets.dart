import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.app.secondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final bool showChevron;

  const InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.showChevron = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final displayValue = (value == null || value!.isEmpty)
        ? 'Не указано'
        : value!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: app.divider)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: app.textSecondary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: app.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 16,
                    color: value == null || value!.isEmpty
                        ? app.hint
                        : app.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron) Icon(Icons.chevron_right, color: app.hint),
        ],
      ),
    );
  }
}

class EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final int? maxLength;
  final int minLines;
  final int maxLines;

  const EditableField({
    required this.label,
    required this.controller,
    this.icon,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.app;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final length = value.text.runes.length;
          final max = maxLength;

          final field = TextField(
            controller: controller,
            maxLength: max,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              alignLabelWithHint: true,
              prefixIcon: icon != null ? Icon(icon, size: 20) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: app.surfaceVariant,
              // Счётчик рисуем поверх поля, а не под ним.
              counterText: '',
              contentPadding: EdgeInsets.fromLTRB(
                16,
                12,
                max == null ? 12 : 68,
                12,
              ),
            ),
          );

          if (max == null) return field;

          return Stack(
            alignment: Alignment.centerRight,
            children: [
              field,
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: IgnorePointer(
                  child: Text(
                    '$length/$max',
                    style: TextStyle(
                      fontSize: 12,
                      color: length >= max ? app.error : app.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  final VoidCallback onConfirmed;
  const LogoutButton({required this.onConfirmed, super.key});

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы действительно хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmed();
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.app.error),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = context.app.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirm(context),
          icon: Icon(Icons.logout, color: errorColor),
          label: Text('Выйти из аккаунта', style: TextStyle(color: errorColor)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: errorColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
