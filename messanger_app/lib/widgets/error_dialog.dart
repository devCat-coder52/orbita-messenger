import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/logger.dart';

class ErrorDialog {
  static void show(BuildContext context, String message, {Object? details}) {
    if (details != null) {
      log.e('$message | $details');
    }
    if (!context.mounted) return;
    final t = AppTokens.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: t.error),
            const SizedBox(width: 8),
            const Text('Что-то пошло не так'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
