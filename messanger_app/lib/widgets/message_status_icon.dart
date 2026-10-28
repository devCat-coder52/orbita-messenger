import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MessageStatusIcon extends StatelessWidget {
  final String status;
  final double size;
  final bool isMe;

  const MessageStatusIcon({
    super.key,
    required this.status,
    this.size = 16.0,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    String iconPath;
    Color iconColor;
    if (!isMe || status == 'forwarding') return const SizedBox.shrink();
    if (status.isNotEmpty) {
      iconPath = 'assets/icons/check_$status.png';
      switch (status) {
        case 'read':
          {
            iconColor = t.secondary;
            break;
          }
        case 'error':
          {
            iconColor = t.error;
            break;
          }
        default:
          iconColor = t.hint;
      }
    } else {
      return SizedBox(width: size);
    }

    return Opacity(
      opacity: 1.0,
      child: Image.asset(
        iconPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: iconColor,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
