import 'package:flutter_test/flutter_test.dart';
import 'package:orbita/services/socket_service.dart';

void main() {
  group('очередь отправки: какие ошибки постоянные', () {
    test('постоянные ошибки убирают сообщение из очереди', () {
      expect(SocketService.isPermanentSendError('EMPTY_MESSAGE'), isTrue);
      expect(SocketService.isPermanentSendError('MESSAGE_TOO_LONG'), isTrue);
      expect(SocketService.isPermanentSendError('NOT_A_MEMBER'), isTrue);
      expect(SocketService.isPermanentSendError('INVALID_CHAT_ID'), isTrue);
      expect(SocketService.isPermanentSendError('INVALID_REPLY'), isTrue);
    });

    test('временные ошибки не считаются постоянными', () {
      expect(SocketService.isPermanentSendError('TIMEOUT'), isFalse);
      expect(SocketService.isPermanentSendError('INTERNAL_ERROR'), isFalse);
      expect(SocketService.isPermanentSendError('OFFLINE'), isFalse);
      expect(SocketService.isPermanentSendError(null), isFalse);
    });
  });
}
