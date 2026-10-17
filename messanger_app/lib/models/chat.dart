import '../utils/time_formatter.dart';

enum ChatMessageType { text, image, voice, file }

class Chat {
  int? chatId;
  final int userId;
  final String userName;
  final String? avatarUrl;
  bool? isOnline;
  bool isPinned;
  int? messageSender;
  int? messageForwarder;
  int? messageTime;
  String? messageText;
  bool? messageIsEncrypted;
  ChatMessageType messageType;
  int unreadCount;

  Chat({
    this.chatId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.isOnline,
    this.isPinned = false,
    this.messageSender,
    this.messageForwarder,
    this.messageTime,
    this.messageText,
    this.messageIsEncrypted = false,
    required this.messageType,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chat_id'],
      userId: json['user_id'],
      userName: json['user_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'],
      isPinned: json['is_pinned'] ?? false,
      messageSender: json['message_sender'],
      messageForwarder: json['message_forwarder'],
      messageTime: switch (json['message_time']) {
        null => null,
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      },
      messageText: json['message_text'],
      messageIsEncrypted: json['message_is_encrypted'],
      messageType: MessageTypeX.parse(json['message_type']),
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  String get formattedTime {
    if (messageTime == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(messageTime!);
    return TimeFormatter.chatListTime(dateTime);
  }

  String get previewText {
    if (messageForwarder != null) return 'Пересланное сообщение';
    return switch (messageType) {
      ChatMessageType.image => 'Фотография',
      ChatMessageType.voice => 'Голосовое сообщение',
      ChatMessageType.file => 'Файл',
      ChatMessageType.text => messageText ?? 'Нет сообщений',
    };
  }

  void togglePin() => isPinned = !isPinned;
}

extension MessageTypeX on ChatMessageType {
  static ChatMessageType parse(Object? value) {
    return switch (value?.toString()) {
      'image' => ChatMessageType.image,
      'voice' => ChatMessageType.voice,
      'file' => ChatMessageType.file,
      _ => ChatMessageType.text,
    };
  }

  String toJson() => name;
}
