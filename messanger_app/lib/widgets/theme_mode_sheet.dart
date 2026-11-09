import 'package:flutter/material.dart';

import '../main.dart' show themeController;
import '../theme/app_theme.dart';

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
