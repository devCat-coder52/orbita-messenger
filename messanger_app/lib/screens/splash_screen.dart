import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Заставка приложения: планета с орбитой и спутником.
class OrbitaSplashScreen extends StatefulWidget {
  const OrbitaSplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OrbitaSplashScreen> createState() => _OrbitaSplashScreenState();
}

const Duration _splashDuration = Duration(milliseconds: 3200);

/// Фазы появления элементов (доли от общего времени).
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
    orbit: _segment(t, 0.12, 0.44, Curves.easeInOutCubic),
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

/// Геометрия картинки в условном холсте 1024×1024.
class _SplashGeometry {
  const _SplashGeometry._();

  static const double canvas = 1024;
  static const double centerX = 512;
  static const double centerY = 512;

  static const double planetY = 500;
  static const double planetRadius = 216;

  static const double orbitRx = 372;
  static const double orbitRy = 205;
  static const double orbitTilt = -22 * math.pi / 180;

  static const double backStroke = 40;
  static const double frontStroke = 26;

  /// Ниже этой линии орбита рисуется поверх планеты.
  static const double frontClipTop = 512;

  static const Rect orbitRect = Rect.fromLTWH(
    -orbitRx,
    -orbitRy,
    orbitRx * 2,
    orbitRy * 2,
  );
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
                            dimension: screen.width.clamp(176.0, 232.0),
                            child: CustomPaint(
                              painter: _OrbitaPainter(
                                background: background,
                                foreground: foreground,
                                orbitMuted: app.splashOrbitMuted,
                                planetProgress: phases.planet,
                                orbitProgress: phases.orbit,
                                satellitePhase: _controller.value,
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

/// Πланета, орбита и спутник с хвостом.
///
/// Порядок рисования задаёт глубину: дальняя половина орбиты и спутник
/// рисуются до планеты (прячутся за ней), ближняя — после (проходят перед).
class _OrbitaPainter extends CustomPainter {
  const _OrbitaPainter({
    required this.background,
    required this.foreground,
    required this.orbitMuted,
    required this.planetProgress,
    required this.orbitProgress,
    required this.satellitePhase,
  });

  final Color background;
  final Color foreground;
  final Color orbitMuted;
  final double planetProgress;
  final double orbitProgress;

  /// 0..1 за время заставки; умножается на число оборотов.
  final double satellitePhase;

  static const int _trailLength = 7;
  static const double _trailStep = 0.032;
  static const double _satelliteRadius = 26;
  static const double _revolutions = 1.35;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _SplashGeometry.canvas);

    _paintRing(canvas, front: false);
    _paintSatellite(canvas, back: true);
    _paintPlanet(canvas);
    _paintRing(canvas, front: true);
    _paintSatellite(canvas, back: false);

    canvas.restore();
  }

  void _paintRing(Canvas canvas, {required bool front}) {
    final opacity = orbitProgress.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    canvas.save();
    if (front) {
      canvas.clipRect(
        const Rect.fromLTWH(
          0,
          _SplashGeometry.frontClipTop,
          _SplashGeometry.canvas,
          _SplashGeometry.canvas - _SplashGeometry.frontClipTop,
        ),
      );
    }
    canvas.translate(_SplashGeometry.centerX, _SplashGeometry.centerY);
    canvas.rotate(_SplashGeometry.orbitTilt);

    if (front) {
      canvas.drawOval(
        _SplashGeometry.orbitRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _SplashGeometry.frontStroke
          ..strokeCap = StrokeCap.round
          ..color = foreground.withValues(alpha: opacity),
      );
    } else {
      canvas.drawOval(
        _SplashGeometry.orbitRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _SplashGeometry.backStroke
          ..strokeCap = StrokeCap.round
          ..color = orbitMuted.withValues(alpha: opacity),
      );
    }

    canvas.restore();
  }

  void _paintPlanet(Canvas canvas) {
    final scale = planetProgress.clamp(0.0, 1.0);
    if (scale <= 0) return;

    canvas.save();
    canvas.translate(_SplashGeometry.centerX, _SplashGeometry.planetY);
    canvas.scale(scale);

    canvas.drawCircle(
      Offset.zero,
      _SplashGeometry.planetRadius,
      Paint()..color = foreground,
    );

    canvas.restore();
  }

  void _paintSatellite(Canvas canvas, {required bool back}) {
    final opacity = orbitProgress.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final phase = satellitePhase * _revolutions;

    for (var i = _trailLength; i >= 0; i--) {
      final pointPhase = phase - i * _trailStep;
      if (_isBack(pointPhase) != back) continue;

      final position = _orbitPoint(pointPhase);
      final fade = 1 - i / (_trailLength + 1);

      if (i == 0) {
        canvas.drawCircle(
          position,
          _satelliteRadius + 18,
          Paint()
            ..color = foreground.withValues(alpha: 0.22 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }

      canvas.drawCircle(
        position,
        i == 0 ? _satelliteRadius : _satelliteRadius * fade * 0.8,
        Paint()..color = foreground.withValues(alpha: opacity * fade),
      );
    }
  }

  Offset _orbitPoint(double phase) {
    final angle = phase * 2 * math.pi - math.pi / 2;
    final localX = _SplashGeometry.orbitRx * math.cos(angle);
    final localY = _SplashGeometry.orbitRy * math.sin(angle);

    final cos = math.cos(_SplashGeometry.orbitTilt);
    final sin = math.sin(_SplashGeometry.orbitTilt);

    return Offset(
      _SplashGeometry.centerX + localX * cos - localY * sin,
      _SplashGeometry.centerY + localX * sin + localY * cos,
    );
  }

  bool _isBack(double phase) {
    final angle = phase * 2 * math.pi - math.pi / 2;
    return math.sin(angle) < 0;
  }

  @override
  bool shouldRepaint(covariant _OrbitaPainter oldDelegate) {
    return oldDelegate.planetProgress != planetProgress ||
        oldDelegate.orbitProgress != orbitProgress ||
        oldDelegate.satellitePhase != satellitePhase ||
        oldDelegate.background != background ||
        oldDelegate.foreground != foreground ||
        oldDelegate.orbitMuted != orbitMuted;
  }
}
