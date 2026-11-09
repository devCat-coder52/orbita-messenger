import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/models/member.dart';
import 'package:orbita/models/message.dart';

void main() {
  test('payload ответа содержит автора и текст исходного сообщения', () {
    final original = Message(
      id: 42,
      sender: const Member(id: 7, name: 'Алиса', avatarUrl: 'uploads/a.png'),
      content: 'привет',
      timeCreate: 1000,
    );

    final payload = Message.buildReplyPayload(original);
    expect(payload, isNotNull);

    final parsed = Message.fromJson(payload!);
    expect(parsed.sender.id, 7);
    expect(parsed.sender.name, 'Алиса');
    expect(parsed.content, 'привет');
    expect(parsed.id, 42);
  });
}
