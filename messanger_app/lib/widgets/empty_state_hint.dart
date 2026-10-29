import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyStateHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Загрузка списка чатов',
      child: _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.hint),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatefulWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({super.key, this.itemCount = 8, this.itemHeight = 72});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0),
      itemBuilder: (context, index) {
        return SizedBox(
          height: widget.itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ShimmerBox(
                  animation: _controller,
                  child: CircleAvatar(radius: 24, backgroundColor: t.divider),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(
                        animation: _controller,
                        child: Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                            color: t.divider,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ShimmerBox(
                        animation: _controller,
                        child: Container(
                          height: 10,
                          width: 200,
                          decoration: BoxDecoration(
                            color: t.divider,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonBanner extends StatefulWidget {
  final double height;

  const SkeletonBanner({super.key, this.height = 36});

  @override
  State<SkeletonBanner> createState() => _SkeletonBannerState();
}

class _SkeletonBannerState extends State<SkeletonBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      label: 'Список обновляется',
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.hint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShimmerBox(
                  animation: _controller,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: t.divider,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _ShimmerBox({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final v = animation.value;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (v * 1.6 - 0.3).clamp(0.0, 1.0),
                (v * 1.6).clamp(0.0, 1.0),
                (v * 1.6 + 0.15).clamp(0.0, 1.0),
              ],
              colors: const [Colors.black, Colors.white, Colors.black],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
