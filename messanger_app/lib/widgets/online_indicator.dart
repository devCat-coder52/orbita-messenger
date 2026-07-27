import 'package:flutter/material.dart';

class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;
  final Color color;
  final Color borderColor;

  const OnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 12.0,
    this.color = Colors.green,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: size * 0.2),
      ),
    );
  }
}
