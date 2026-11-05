import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalTextScreen extends StatelessWidget {
  const LegalTextScreen({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Редакция от $updatedAt',
            style: TextStyle(fontSize: 13, color: t.textSecondary),
          ),
          const SizedBox(height: 20),
          for (final section in sections) ...[
            Text(
              section.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: TextStyle(fontSize: 14, height: 1.5, color: t.textPrimary),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
