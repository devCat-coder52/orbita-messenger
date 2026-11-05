import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/models/member.dart';
import 'package:orbita/models/message.dart';
import 'package:orbita/screens/chat/message_bubble.dart';
import 'package:orbita/theme/app_theme.dart';
import 'package:orbita/widgets/message_status_icon.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput:
          'BASE_URL=http://localhost:3000\n'
          'SOCKET_URL=http://localhost:3000\n'
          r'BASE_URL_API=${BASE_URL}/api',
    );
  });

  Message makeMessage({
    String content = 'Привет',
    bool isEdited = false,
    MessageStatus status = MessageStatus.sent,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) => Message(
    id: 1,
    sender: const Member(id: 1, name: 'Тест'),
    content: content,
    timeCreate: 1700000000000,
    status: status,
    isEdited: isEdited,
    fileUrl: fileUrl,
    fileName: fileName,
    fileSize: fileSize,
  );

  Widget wrap(Widget child) => MaterialApp(
    theme: AppThemes.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: child),
      ),
    ),
  );

  Future<void> pumpBubble(WidgetTester tester, Widget bubble) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(bubble));
    await tester.pump();
  }

  ChatMessageBubbleWidget bubble({
    required Message message,
    int? myId = 1,
    String timeString = '12:34',
    String status = 'sent',
  }) => ChatMessageBubbleWidget(
    message: message,
    myId: myId,
    timeString: timeString,
    status: status,
    selectedCount: 0,
  );

  testWidgets('у текстового сообщения есть время', (tester) async {
    await pumpBubble(tester, bubble(message: makeMessage()));

    expect(tester.takeException(), isNull);
    expect(find.text('12:34'), findsOneWidget);
  });

  testWidgets('длинный текст переносится и не переполняет пузырь', (
    tester,
  ) async {
    await pumpBubble(
      tester,
      bubble(message: makeMessage(content: 'Очень длинное сообщение ' * 20)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('12:34'), findsOneWidget);
  });

  testWidgets('у файла тоже есть время и размер', (tester) async {
    await pumpBubble(
      tester,
      bubble(
        message: makeMessage(
          content: '',
          fileUrl: '/uploads/messages/files/doc.pdf',
          fileName: 'документ.pdf',
          fileSize: 2048,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('документ.pdf'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
  });

  testWidgets('изменённое сообщение помечается «изм.»', (tester) async {
    await pumpBubble(
      tester,
      bubble(message: makeMessage(content: 'Правленное', isEdited: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('изм.'), findsOneWidget);
  });

  testWidgets('у входящего сообщения нет галочек статуса', (tester) async {
    await pumpBubble(tester, bubble(message: makeMessage(), myId: 2));

    expect(tester.takeException(), isNull);
    expect(find.byType(MessageStatusIcon), findsNothing);
  });

  testWidgets('у своего сообщения статус отображается', (tester) async {
    await pumpBubble(
      tester,
      bubble(message: makeMessage(), myId: 1, status: 'read'),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(MessageStatusIcon), findsOneWidget);
  });

  testWidgets('время стоит в углу последней строки, а не отдельной строкой', (
    tester,
  ) async {
    await pumpBubble(tester, bubble(message: makeMessage(content: 'Привет')));

    expect(tester.takeException(), isNull);

    final stack = find
        .descendant(
          of: find.byType(ChatMessageBubbleWidget),
          matching: find.byType(Stack),
        )
        .first;
    final stackRect = tester.getRect(stack);
    final metaRect = tester.getRect(find.byType(MessageStatusIcon));

    expect(
      (metaRect.right - stackRect.right).abs() <= 1.0,
      isTrue,
      reason: 'плашка должна быть прижата к правому краю текста',
    );
    expect(
      (metaRect.bottom - (stackRect.bottom - 1)).abs() <= 1.0,
      isTrue,
      reason: 'плашка должна быть у нижнего края последней строки',
    );

    final bubbleHeight = tester
        .getSize(find.byType(ChatMessageBubbleWidget))
        .height;
    expect(
      bubbleHeight < 48,
      isTrue,
      reason: 'плашка занимает последнюю строку, а не отдельную',
    );
  });

  testWidgets('в длинном сообщении плашка не наезжает на текст', (
    tester,
  ) async {
    await pumpBubble(
      tester,
      bubble(message: makeMessage(content: 'Слово ' * 40)),
    );

    expect(tester.takeException(), isNull);

    final stack = find
        .descendant(
          of: find.byType(ChatMessageBubbleWidget),
          matching: find.byType(Stack),
        )
        .first;
    final stackRect = tester.getRect(stack);
    final metaRect = tester.getRect(find.byType(MessageStatusIcon));

    expect((metaRect.right - stackRect.right).abs() <= 1.0, isTrue);
    expect(metaRect.width < stackRect.width, isTrue);
  });
}
