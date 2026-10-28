import 'package:flutter/material.dart';

import '../main.dart' show themeController;
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

Future<void> showThemeModeSheet(BuildContext context) async {
  Navigator.of(context).pop();
  await Future<void>.delayed(const Duration(milliseconds: 120));
  if (!context.mounted) return;

  final selected = await showModalBottomSheet<ThemeModePreference>(
    context: context,
    builder: (sheetContext) {
      final current = themeController.preference;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Оформление',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            for (final option in _options)
              ListTile(
                leading: Icon(option.icon),
                title: Text(option.label),
                trailing: current == option.mode
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(sheetContext).colorScheme.secondary,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, option.mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (selected != null) {
    await themeController.setPreference(selected);
  }
}

class _ThemeOption {
  const _ThemeOption(this.mode, this.label, this.icon);
  final ThemeModePreference mode;
  final String label;
  final IconData icon;
}

const _options = [
  _ThemeOption(
    ThemeModePreference.system,
    'Как в системе',
    Icons.brightness_auto_outlined,
  ),
  _ThemeOption(
    ThemeModePreference.light,
    'Светлая тема',
    Icons.light_mode_outlined,
  ),
  _ThemeOption(
    ThemeModePreference.dark,
    'Тёмная тема',
    Icons.dark_mode_outlined,
  ),
];

class ThemeQuickToggle extends StatelessWidget {
  const ThemeQuickToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Включить светлую тему' : 'Включить тёмную тему',
      onPressed: () => themeController.animateToggle(context),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.7, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
          key: ValueKey(isDark),
          color: t.textOnHeader,
        ),
      ),
    );
  }
}
