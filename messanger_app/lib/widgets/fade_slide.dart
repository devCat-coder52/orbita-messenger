import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  final Widget child;

  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  final Object? animationKey;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 0.35),
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
    this.animationKey,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: animationKey == null ? null : ValueKey(animationKey),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(beginOffset.dx * (1 - t), beginOffset.dy * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
