import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = context.app;
    return Semantics(
      label: count >= 100
          ? 'Более 99 непрочитанных сообщений'
          : '$count непрочитанных сообщений',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(count),
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: t.badgeUnread,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              count >= 100 ? '99+' : '$count',
              style: TextStyle(
                color: t.textOnAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
