library;

enum LinkKind { text, url, email, phone }

class LinkSegment {
  const LinkSegment(this.value, this.kind);

  final String value;
  final LinkKind kind;

  bool get isLink => kind != LinkKind.text;

  String get launchUri {
    switch (kind) {
      case LinkKind.email:
        return 'mailto:$value';
      case LinkKind.phone:
        return 'tel:${value.replaceAll(RegExp(r'[^\d+]'), '')}';
      case LinkKind.url:
        return value.toLowerCase().startsWith('www.')
            ? 'https://$value'
            : value;
      case LinkKind.text:
        return value;
    }
  }
}

final RegExp _linkPattern = RegExp(
  r'https?://[^\s<>"]+'
  r'|www\.[^\s<>"]+'
  r'|[\w.+-]+@[\w-]+\.[\w.-]+'
  r'|\+?\d[\d\s().-]{7,}\d',
  caseSensitive: false,
);

const String _trailingPunctuation = '.,;:!?)]}»"\'…';

List<LinkSegment> detectLinks(String text) {
  if (text.isEmpty) return const [];

  final segments = <LinkSegment>[];
  var index = 0;

  for (final match in _linkPattern.allMatches(text)) {
    if (match.start > index) {
      segments.add(
        LinkSegment(text.substring(index, match.start), LinkKind.text),
      );
    }

    final raw = match.group(0)!;
    var value = raw;
    var trailing = '';

    while (value.isNotEmpty &&
        _trailingPunctuation.contains(value[value.length - 1])) {
      trailing = value[value.length - 1] + trailing;
      value = value.substring(0, value.length - 1);
    }

    if (value.isEmpty) {
      segments.add(LinkSegment(raw, LinkKind.text));
    } else {
      segments.add(LinkSegment(value, _kindOf(value)));
      if (trailing.isNotEmpty) {
        segments.add(LinkSegment(trailing, LinkKind.text));
      }
    }

    index = match.end;
  }

  if (index < text.length) {
    segments.add(LinkSegment(text.substring(index), LinkKind.text));
  }

  return segments;
}

LinkKind _kindOf(String value) {
  final lower = value.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('www.')) {
    return LinkKind.url;
  }
  if (value.contains('@')) return LinkKind.email;
  return LinkKind.phone;
}
