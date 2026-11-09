import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Свайп вправо по сообщению — ответ на него, как в Telegram.
///
/// Жест не мешает вертикальной прокрутке: горизонтальный drag побеждает
/// в арене только при явном горизонтальном движении.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  static const double maxOffset = 72;
  static const double threshold = 48;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _drag = 0;

  void _reset() {
    if (_drag == 0) return;
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    if (!widget.enabled) return widget.child;

    final progress = (_drag / SwipeToReply.threshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        final next = (_drag + details.delta.dx).clamp(
          0.0,
          SwipeToReply.maxOffset,
        );
        if (next != _drag) setState(() => _drag = next);
      },
      onHorizontalDragEnd: (_) {
        if (_drag >= SwipeToReply.threshold) {
          HapticFeedback.selectionClick();
          widget.onReply();
        }
        _reset();
      },
      onHorizontalDragCancel: _reset,
      child: Stack(
        children: [
          if (_drag > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: t.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply,
                      size: 18,
                      color: t.secondary,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
