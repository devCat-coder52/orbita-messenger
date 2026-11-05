import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OrbitaSplashScreen extends StatefulWidget {
  const OrbitaSplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OrbitaSplashScreen> createState() => _OrbitaSplashScreenState();
}

const Duration _splashDuration = Duration(milliseconds: 3200);

class _SplashPhases {
  const _SplashPhases({
    required this.planet,
    required this.orbit,
    required this.copy,
    required this.progress,
    required this.exit,
  });

  factory _SplashPhases.at(double t) => _SplashPhases(
    planet: _segment(t, 0.06, 0.28, Curves.easeOutBack),
    orbit: _segment(t, 0.13, 0.45, Curves.easeInOutCubic),
    copy: _segment(t, 0.30, 0.53, Curves.easeOutCubic),
    progress: _segment(t, 0.45, 0.88, Curves.easeInOutCubic),
    exit: 1 - _segment(t, 0.88, 1, Curves.easeInOut),
  );

  final double planet;
  final double orbit;
  final double copy;
  final double progress;
  final double exit;

  static double _segment(double t, double start, double end, Curve curve) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return curve.transform((t - start) / (end - start));
  }
}

abstract final class _IconGeometry {
  static const double canvas = 1024;
  static const double cardRadius = 224;

  static const double centerX = 512;
  static const double centerY = 512;

  static const double planetY = 500;
  static const double planetRadius = 216;

  static const double planetHaloRadius = 230;
  static const double planetHaloStroke = 28;

  static const double orbitWidth = 672;
  static const double orbitHeight = 284;
  static const double orbitStroke = 48;

  static const double frontGapStroke = 62;
  static const double frontStroke = 34;

  static const double frontClipTop = 500;

  static const double tilt = -24 * math.pi / 180;
}

class _OrbitaSplashScreenState extends State<OrbitaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _splashDuration)
      ..addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onFinished?.call();
    }
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

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final background = app.headerBackground;
    final foreground = app.splashForeground;
    final screen = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phases = _SplashPhases.at(_controller.value);

        return Opacity(
          opacity: phases.exit,
          child: Scaffold(
            backgroundColor: background,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.16),
                  radius: 0.58,
                  colors: [app.splashGlow, background],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -screen.height * 0.02),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: screen.width.clamp(168.0, 224.0),
                            child: CustomPaint(
                              painter: _OrbitaIconPainter(
                                background: background,
                                foreground: foreground,
                                orbitMuted: app.splashOrbitMuted,
                                planetProgress: phases.planet,
                                orbitProgress: phases.orbit,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SplashTitle(
                            progress: phases.copy,
                            titleColor: foreground,
                            subtitleColor: app.splashSubtitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: math.max(44, screen.height * 0.07),
                    child: Center(
                      child: Opacity(
                        opacity: phases.progress > 0 ? 1 : 0,
                        child: _SplashProgressBar(
                          progress: phases.progress,
                          color: foreground,
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

class _SplashTitle extends StatelessWidget {
  const _SplashTitle({
    required this.progress,
    required this.titleColor,
    required this.subtitleColor,
  });

  final double progress;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - progress)),
        child: Column(
          children: [
            Text(
              'Orbita',
              style: TextStyle(
                color: titleColor,
                fontSize: 48,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Мессенджер для своих',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  const _SplashProgressBar({required this.progress, required this.color});

  static const double _width = 112;
  static const double _height = 3;

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: _width,
        height: _height,
        color: color.withValues(alpha: 0.14),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

class _OrbitaIconPainter extends CustomPainter {
  const _OrbitaIconPainter({
    required this.background,
    required this.foreground,
    required this.orbitMuted,
    required this.planetProgress,
    required this.orbitProgress,
  });

  final Color background;
  final Color foreground;
  final Color orbitMuted;
  final double planetProgress;
  final double orbitProgress;

  static const Rect _cardRect = Rect.fromLTWH(
    0,
    0,
    _IconGeometry.canvas,
    _IconGeometry.canvas,
  );

  static const Rect _orbitRect = Rect.fromLTWH(
    -336,
    -142,
    _IconGeometry.orbitWidth,
    _IconGeometry.orbitHeight,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _IconGeometry.canvas);

    _paintCard(canvas);
    _paintBackOrbit(canvas);
    _paintPlanet(canvas);
    _paintFrontOrbit(canvas);

    canvas.restore();
  }

  void _paintCard(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _cardRect,
        const Radius.circular(_IconGeometry.cardRadius),
      ),
      Paint()..color = background,
    );
  }

  void _paintBackOrbit(Canvas canvas) {
    canvas.save();
    canvas.translate(_IconGeometry.centerX, _IconGeometry.centerY);
    canvas.rotate(_IconGeometry.tilt);
    _drawOrbit(
      canvas,
      _orbitRect,
      Paint()
        ..color = orbitMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = _IconGeometry.orbitStroke
        ..strokeCap = StrokeCap.round,
      orbitProgress,
    );
    canvas.restore();
  }

  void _paintPlanet(Canvas canvas) {
    canvas.save();
    canvas.translate(_IconGeometry.centerX, _IconGeometry.planetY);
    canvas.scale(planetProgress);

    canvas.drawCircle(
      Offset.zero,
      _IconGeometry.planetHaloRadius,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = _IconGeometry.planetHaloStroke,
    );
    canvas.drawCircle(
      Offset.zero,
      _IconGeometry.planetRadius,
      Paint()..color = foreground,
    );
    canvas.restore();
  }

  void _paintFrontOrbit(Canvas canvas) {
    canvas.save();
    canvas.clipRect(
      const Rect.fromLTWH(
        0,
        _IconGeometry.frontClipTop,
        _IconGeometry.canvas,
        _IconGeometry.canvas - _IconGeometry.frontClipTop,
      ),
    );
    canvas.translate(_IconGeometry.centerX, _IconGeometry.centerY);
    canvas.rotate(_IconGeometry.tilt);

    _drawOrbit(
      canvas,
      _orbitRect,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = _IconGeometry.frontGapStroke,
      orbitProgress,
    );
    _drawOrbit(
      canvas,
      _orbitRect,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = _IconGeometry.frontStroke
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
        oldDelegate.orbitProgress != orbitProgress ||
        oldDelegate.background != background ||
        oldDelegate.foreground != foreground ||
        oldDelegate.orbitMuted != orbitMuted;
  }
}
