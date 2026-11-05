import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

/// Экран «О приложении»: версия, документы и контакты.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          const _Header(),
          const SizedBox(height: 28),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Политика конфиденциальности',
            onTap: () => _open(context, const PrivacyPolicyScreen()),
          ),
          Divider(height: 1, color: t.divider),
          _LinkTile(
            icon: Icons.description_outlined,
            title: 'Условия использования',
            onTap: () => _open(context, const TermsScreen()),
          ),
          const SizedBox(height: 28),
          Text(
            'Это бета-версия: возможны сбои и потери данных. '
            'Перед использованием в важной переписке сделайте резервную копию.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            '© ${DateTime.now().year} ${AppInfo.name}',
            style: TextStyle(fontSize: 12, color: t.hint),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: t.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.blur_circular, size: 52, color: t.splashForeground),
        ),
        const SizedBox(height: 16),
        Text(
          AppInfo.name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppInfo.tagline,
          style: TextStyle(fontSize: 14, color: t.textSecondary),
        ),
        const SizedBox(height: 10),
        Text(
          'Версия ${AppInfo.version}',
          style: TextStyle(fontSize: 13, color: t.hint),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: t.secondary),
      title: Text(title, style: TextStyle(color: t.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: t.hint),
      onTap: onTap,
    );
  }
}
