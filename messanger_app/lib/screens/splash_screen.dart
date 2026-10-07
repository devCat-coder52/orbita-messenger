import 'dart:math' as math;

import 'package:flutter/material.dart';

const _background = Color(0xFF2C3E50);
const _orbitMuted = Color(0xFF91A5B8);
const _foreground = Color(0xFFF7FAFC);

class OrbitaSplashScreen extends StatefulWidget {
  const OrbitaSplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OrbitaSplashScreen> createState() => _OrbitaSplashScreenState();
}

class _OrbitaSplashScreenState extends State<OrbitaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3200),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onFinished?.call();
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;

    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.duration = const Duration(milliseconds: 1);
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double start, double end, Curve curve) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: curve),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final planet = _phase(0.06, 0.28, Curves.easeOutBack);
        final orbit = _phase(0.13, 0.45, Curves.easeInOutCubic);
        final copy = _phase(0.30, 0.53, Curves.easeOutCubic);
        final progress = _phase(0.45, 0.88, Curves.easeInOutCubic);
        final exit = 1 - _phase(0.88, 1, Curves.easeInOut);

        return Opacity(
          opacity: exit,
          child: Scaffold(
            backgroundColor: _background,
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.16),
                  radius: 0.58,
                  colors: [Color(0x215B7186), _background],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -MediaQuery.sizeOf(context).height * 0.02,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: MediaQuery.sizeOf(
                              context,
                            ).width.clamp(168.0, 224.0),
                            child: CustomPaint(
                              painter: _OrbitaIconPainter(
                                planetProgress: planet,
                                orbitProgress: orbit,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Opacity(
                            opacity: copy,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - copy)),
                              child: const Column(
                                children: [
                                  Text(
                                    'Orbita',
                                    style: TextStyle(
                                      color: _foreground,
                                      fontSize: 48,
                                      height: 1,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -1.8,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Мессенджер для своих',
                                    style: TextStyle(
                                      color: Color(0xFFB9C7D3),
                                      fontSize: 14,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: math.max(
                      44,
                      MediaQuery.sizeOf(context).height * 0.07,
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: progress > 0 ? 1 : 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 112,
                            height: 3,
                            color: _foreground.withValues(alpha: 0.14),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              heightFactor: 1,
                              child: const ColoredBox(color: _foreground),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbitaIconPainter extends CustomPainter {
  const _OrbitaIconPainter({
    required this.planetProgress,
    required this.orbitProgress,
  });

  final double planetProgress;
  final double orbitProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024;
    canvas.scale(scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        const Radius.circular(224),
      ),
      Paint()..color = _background,
    );

    final orbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: 672,
      height: 284,
    );

    canvas.save();
    canvas.translate(512, 512);
    canvas.rotate(-24 * math.pi / 180);
    _drawOrbit(
      canvas,
      orbitRect,
      Paint()
        ..color = _orbitMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 48
        ..strokeCap = StrokeCap.round,
      orbitProgress,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(512, 500);
    canvas.scale(planetProgress);
    canvas.drawCircle(
      Offset.zero,
      230,
      Paint()
        ..color = _background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28,
    );
    canvas.drawCircle(Offset.zero, 216, Paint()..color = _foreground);
    canvas.restore();

    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 500, 1024, 524));
    canvas.translate(512, 512);
    canvas.rotate(-24 * math.pi / 180);
    _drawOrbit(
      canvas,
      orbitRect,
      Paint()
        ..color = _background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 80
        ..strokeCap = StrokeCap.round,
      orbitProgress,
    );
    _drawOrbit(
      canvas,
      orbitRect,
      Paint()
        ..color = _foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round,
      orbitProgress,
    );
    canvas.restore();
  }

  void _drawOrbit(Canvas canvas, Rect bounds, Paint paint, double progress) {
    if (progress <= 0) return;

    if (progress >= 0.999) {
      canvas.drawOval(bounds, paint);
      return;
    }

    canvas.drawArc(bounds, 0, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitaIconPainter oldDelegate) {
    return oldDelegate.planetProgress != planetProgress ||
        oldDelegate.orbitProgress != orbitProgress;
  }
}
