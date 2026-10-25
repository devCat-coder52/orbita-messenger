import 'dart:async';

import 'package:flutter/widgets.dart' show ScrollController;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/models/member.dart';
import 'package:orbita/models/message.dart';
import 'package:orbita/screens/chat/search_controller.dart';

/// Тесты чистой логики кэш-слоя, не требующие плагина sqflite
/// (работа с самой БД покрывается ручными сценариями на устройстве:
/// офлайн-запуск, добор истории при прокрутке, поиск по кэшу).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Message msg(int id, String content, int time) => Message(
    id: id,
    sender: Member(id: 1, name: 'Test'),
    content: content,
    timeCreate: time,
  );

  group('Message serialization round-trip (формат строк кэша)', () {
    test('toJson/fromJson сохраняет id, контент и время', () {
      final original = msg(42, 'привет, мир', 1700000000000);
      final restored = Message.fromJson(original.toJson());
      expect(restored.id, 42);
      expect(restored.content, 'привет, мир');
      expect(restored.timeCreate, 1700000000000);
      expect(original.toJson()['time_create'], '1700000000000');
    });

    test('temp-сообщения (id == null) не должны попадать в кэш', () {
      final temp = Message(
        sender: const Member(id: 1, name: 'Test'),
        content: 'x',
        timeCreate: 1,
        isTemp: true,
      );
      expect(temp.id, isNull);
    });
  });

  group('ChatSearchController + fallback-поиск по кэшу', () {
    late List<Message> list;

    setUp(() {
      list = [msg(1, 'альфа', 10), msg(2, 'бета', 20), msg(3, 'гамма', 30)];
    });

    ChatSearchController build({
      Future<List<int>> Function(String query)? onCacheFallback,
    }) => ChatSearchController(
      scrollController: ScrollController(),
      messages: () => list,
      onCacheFallback: onCacheFallback,
    );

    test('синхронный поиск находит индексы в загруженном окне', () {
      final c = build();
      c.performSearch('ета');
      expect(c.results, [1]);
      expect(c.currentIndex, 0);
    });

    test('fallback из кэша мержит индексы без дублей', () async {
      final c = build(onCacheFallback: (_) async => [1, 2]);
      c.performSearch('ета');
      expect(c.isSearchingCache, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(c.results, [1, 2]);
      expect(c.isSearchingCache, isFalse);
    });

    test('applyExtra получает только индексы из кэша', () async {
      final c = build(onCacheFallback: (_) async => [2]);
      List<int>? applied;
      c.performSearch('ета', applyExtra: (extra) => applied = extra);
      await Future<void>.delayed(Duration.zero);
      expect(applied, [2]);
      expect(c.results, [1, 2]);
    });

    test('сменившийся запрос игнорирует устаревший результат кэша', () async {
      final gates = <Completer<List<int>>>[];
      final c = build(
        onCacheFallback: (_) {
          final g = Completer<List<int>>();
          gates.add(g);
          return g.future;
        },
      );
      c.performSearch('старый');
      c.performSearch('новый');
      expect(c.isSearchingCache, isTrue);
      gates[0].complete([2]);
      await Future<void>.delayed(Duration.zero);
      expect(c.query, 'новый');
      expect(c.results, isEmpty);
      expect(c.isSearchingCache, isTrue);
      gates[1].complete(const []);
      await Future<void>.delayed(Duration.zero);
      expect(c.results, isEmpty);
      expect(c.isSearchingCache, isFalse);
    });

    test(
      'баг A→B→A: ответ по строковому совпадению запроса не принимается',
      () async {
        final gates = <Completer<List<int>>>[];
        final c = build(
          onCacheFallback: (_) {
            final g = Completer<List<int>>();
            gates.add(g);
            return g.future;
          },
        );
        c.performSearch('альфа');
        c.performSearch('бета');
        c.performSearch('альфа');
        expect(c.query, 'альфа');
        gates[2].complete([0]);
        gates[0].complete([1, 2]);
        await Future<void>.delayed(Duration.zero);
        expect(c.results, [0]);
        expect(c.isSearchingCache, isFalse);
      },
    );

    test('пустой запрос сбрасывает состояние', () {
      final c = build();
      c.performSearch('альфа');
      c.performSearch('');
      expect(c.results, isEmpty);
      expect(c.currentIndex, -1);
      expect(c.isSearchingCache, isFalse);
    });
  });
}
