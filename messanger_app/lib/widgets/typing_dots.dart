import 'package:flutter/material.dart';

class TypingDots extends StatefulWidget {
  final Color? color;
  final double size;

  const TypingDots({super.key, this.color, this.size = 6});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.white70;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.25) % 1.0;
            final bounce = Curves.easeOutQuad.transform(
              t < 0.5 ? t * 2 : (1 - t) * 2,
            );
            return Container(
              width: widget.size,
              height: widget.size,
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : widget.size * 0.6,
                bottom: bounce * widget.size * 0.9,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.5 + bounce * 0.5),
              ),
            );
          }),
        );
      },
    );
  }
}
