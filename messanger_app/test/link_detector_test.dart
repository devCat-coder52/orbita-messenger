import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/utils/link_detector.dart';

void main() {
  test('текст со ссылкой делится на части', () {
    final segments = detectLinks('Смотри http://example.com/a?b=1 и всё');

    expect(segments.map((s) => s.kind), [
      LinkKind.text,
      LinkKind.url,
      LinkKind.text,
    ]);
    expect(segments[1].value, 'http://example.com/a?b=1');
    expect(segments[1].launchUri, 'http://example.com/a?b=1');
  });

  test('адрес без схемы получает https', () {
    final segments = detectLinks('www.example.com');

    expect(segments.single.kind, LinkKind.url);
    expect(segments.single.launchUri, 'https://www.example.com');
  });

  test('точка в конце ссылки не входит в адрес', () {
    final segments = detectLinks('См. https://example.com.');

    final link = segments.firstWhere((s) => s.isLink);
    expect(link.value, 'https://example.com');
    expect(segments.last.value, '.');
    expect(segments.last.kind, LinkKind.text);
  });

  test('почта открывается через mailto', () {
    final segments = detectLinks('пиши на me@example.com');

    final link = segments.firstWhere((s) => s.isLink);
    expect(link.kind, LinkKind.email);
    expect(link.launchUri, 'mailto:me@example.com');
  });

  test('телефон нормализуется в tel:', () {
    final segments = detectLinks('звони +7 (999) 123-45-67');

    final link = segments.firstWhere((s) => s.isLink);
    expect(link.kind, LinkKind.phone);
    expect(link.launchUri, 'tel:+79991234567');
  });

  test('время не считается телефоном', () {
    final segments = detectLinks('в 12:34 встретимся');

    expect(segments.every((s) => !s.isLink), isTrue);
  });

  test('обычный текст остаётся одним фрагментом', () {
    final segments = detectLinks('просто текст');

    expect(segments.length, 1);
    expect(segments.single.kind, LinkKind.text);
  });

  test('пустая строка даёт пустой список', () {
    expect(detectLinks(''), isEmpty);
  });
}
