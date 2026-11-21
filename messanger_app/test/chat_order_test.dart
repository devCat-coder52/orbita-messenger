import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/models/chat.dart';

Chat chat({
  required int id,
  required int time,
  bool pinned = false,
  int userId = 1,
}) {
  return Chat(
    chatId: id,
    userId: userId,
    userName: 'Чат $id',
    messageTime: time,
    messageType: ChatMessageType.text,
    messageText: 'текст',
    isPinned: pinned,
  );
}

void main() {
  group('порядок списка чатов', () {
    test('свежее сообщение поднимает чат выше', () {
      final old = chat(id: 1, time: 1000);
      final fresh = chat(id: 2, time: 2000);

      final list = [old, fresh]..sort(Chat.compareForList);

      expect(list.map((c) => c.chatId), [2, 1]);
    });

    test('системный чат с меньшим chat_id не всплывает наверх', () {
      // Системный чат создаётся первым, поэтому у него самый маленький id,
      // но последнее сообщение в нём старше — он должен быть ниже.
      final system = chat(id: 1, time: 1000, userId: -1);
      final dialog = chat(id: 2, time: 5000);

      final list = [system, dialog]..sort(Chat.compareForList);

      expect(list.map((c) => c.chatId), [2, 1]);
    });

    test('закреплённый чат выше более свежего незакреплённого', () {
      final pinnedOld = chat(id: 1, time: 1000, pinned: true);
      final fresh = chat(id: 2, time: 9000);

      final list = [fresh, pinnedOld]..sort(Chat.compareForList);

      expect(list.map((c) => c.chatId), [1, 2]);
    });

    test('чат без сообщений уходит в конец', () {
      final empty = chat(id: 1, time: 0);
      final withMessage = chat(id: 2, time: 10);

      final list = [empty, withMessage]..sort(Chat.compareForList);

      expect(list.map((c) => c.chatId), [2, 1]);
    });

    test('при равном времени порядок устойчивый и не зависит от входа', () {
      final a = chat(id: 3, time: 1000);
      final b = chat(id: 7, time: 1000);

      final direct = [a, b]..sort(Chat.compareForList);
      final reversed = [b, a]..sort(Chat.compareForList);

      expect(direct.map((c) => c.chatId), reversed.map((c) => c.chatId));
      expect(direct.map((c) => c.chatId), [3, 7]);
    });
  });
}
