import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/models/member.dart';
import 'package:orbita/models/message.dart';
import 'package:orbita/screens/chat/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Message message({int? id, String content = 'привет'}) => Message(
    id: id,
    sender: const Member(id: 1, name: 'Тест'),
    content: content,
    timeCreate: 1700000000000,
  );

  group('ChatController: редактирование', () {
    test('первый тап начинает правку, повторный — отменяет', () {
      final controller = ChatController();
      final msg = message(id: 7);

      expect(controller.changeEditing(msg), 'привет');
      expect(controller.editingMessageId, 7);

      expect(controller.changeEditing(msg), '');
      expect(controller.editingMessageId, isNull);

      controller.dispose();
    });

    test('сообщение без id и пересылаемое не редактируются', () {
      final controller = ChatController();

      expect(controller.changeEditing(message()), isNull);

      final forwarding = message(
        id: 1,
      ).copyWith(status: MessageStatus.forwarding);
      expect(controller.changeEditing(forwarding), 'привет');
      controller.dispose();
    });
  });

  group('ChatController: ответ на сообщение', () {
    test('buildReply выставляет ответ и снимает режим правки', () {
      final controller = ChatController();
      final msg = message(id: 3);

      controller.changeEditing(msg);
      expect(controller.editingMessageId, 3);

      expect(controller.buildReply(msg), isNotNull);
      expect(controller.replyingTo, isNotNull);
      expect(controller.editingMessageId, isNull);

      controller.cancelReply();
      expect(controller.replyingTo, isNull);

      controller.dispose();
    });

    test('на сообщение без id ответить нельзя', () {
      final controller = ChatController();
      expect(controller.buildReply(message()), isNull);
      expect(controller.replyingTo, isNull);
      controller.dispose();
    });
  });

  group('ChatController: прокрутка', () {
    test('позиция у низа считается «внизу», у верха — нет', () {
      final controller = ChatController();
      expect(controller.atBottom, isTrue);

      controller.updateScrollState(pixels: 500, maxExtent: 1000);
      expect(controller.atBottom, isFalse);

      controller.updateScrollState(pixels: 10, maxExtent: 1000);
      expect(controller.atBottom, isTrue);

      controller.dispose();
    });

    test('markAtBottom возвращает состояние «внизу»', () {
      final controller = ChatController();
      controller.updateScrollState(pixels: 900, maxExtent: 1000);
      expect(controller.atBottom, isFalse);

      controller.markAtBottom();
      expect(controller.atBottom, isTrue);
      expect(controller.newMessagesCount, 0);

      controller.dispose();
    });
  });

  group('История и режим пересылки', () {
    test('пересылаемые сообщения переживают замену истории', () {
      final forwarded = message(
        id: 10,
      ).copyWith(status: MessageStatus.forwarding);
      final history = [message(id: 1), message(id: 2, content: 'второе')];
      final current = [message(id: 2, content: 'второе'), forwarded];

      final merged = mergeHistoryPreservingLocal(history, current);

      expect(merged.map((m) => m.id), [1, 2, 10]);
      expect(merged.last.status, MessageStatus.forwarding);
    });

    test('без пересылки история просто заменяется', () {
      final history = [message(id: 1), message(id: 2)];
      final current = [message(id: 2)];

      final merged = mergeHistoryPreservingLocal(history, current);

      expect(merged.map((m) => m.id), [1, 2]);
    });

    test('после реконнекта добавляются только пропущенные сообщения', () {
      final current = [message(id: 1), message(id: 2)];
      final fresh = [message(id: 2), message(id: 3, content: 'пропущенное')];

      final missed = mergeMissedMessages(current, fresh);

      expect(missed.map((m) => m.id), [3]);
      expect(missed.single.content, 'пропущенное');
    });

    test('локальные сообщения без id не считаются дублями', () {
      final current = [message(id: null), message(id: 1)];
      final fresh = [message(id: 1), message(id: 2)];

      final missed = mergeMissedMessages(current, fresh);

      expect(missed.map((m) => m.id), [2]);
    });
  });
}
