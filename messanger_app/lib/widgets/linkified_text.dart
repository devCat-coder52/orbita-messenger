import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/link_detector.dart';

class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkColor,
    required this.reserve,
    required this.reserveHeight,
    this.onLinkTap,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;
  final double reserve;
  final double reserveHeight;
  final void Function(String uri)? onLinkTap;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.linkColor != widget.linkColor ||
        oldWidget.reserve != widget.reserve ||
        oldWidget.reserveHeight != widget.reserveHeight) {
      _rebuildSpans();
    }
  }

  void _rebuildSpans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final linkStyle = widget.style.copyWith(
      color: widget.linkColor,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor,
    );

    final spans = <InlineSpan>[];
    for (final segment in detectLinks(widget.text)) {
      if (!segment.isLink) {
        spans.add(TextSpan(text: segment.value));
        continue;
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onLinkTap?.call(segment.launchUri);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: segment.value, style: linkStyle, recognizer: recognizer),
      );
    }

    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: SizedBox(width: widget.reserve, height: widget.reserveHeight),
      ),
    );

    _spans = spans;
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _spans), style: widget.style);
  }
}
