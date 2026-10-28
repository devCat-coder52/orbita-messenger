import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const OnlineIndicator({super.key, required this.isOnline, this.size = 12.0});

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    return AnimatedScale(
      scale: isOnline ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.success,
          shape: BoxShape.circle,
          border: Border.all(color: t.surface, width: size * 0.2),
        ),
      ),
    );
  }
}
