import '../utils/json_utils.dart';
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
      chatId: asInt(json['chat_id']),
      userId: asIntOr(json['user_id'], -1),
      userName: (json['user_name'] ?? 'Чат').toString(),
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] == true,
      isPinned: json['is_pinned'] == true,
      messageSender: asInt(json['message_sender']),
      messageForwarder: asInt(json['message_forwarder']),
      messageTime: asInt(json['message_time']),
      messageText: json['message_text'] as String?,
      messageIsEncrypted: json['message_is_encrypted'] == true,
      messageType: MessageTypeX.parse(json['message_type']),
      unreadCount: asIntOr(json['unread_count'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'chat_id': chatId,
    'user_id': userId,
    'user_name': userName,
    'avatar_url': avatarUrl,
    'is_online': isOnline,
    'is_pinned': isPinned,
    'message_sender': messageSender,
    'message_forwarder': messageForwarder,
    'message_time': messageTime,
    'message_text': messageText,
    'message_is_encrypted': messageIsEncrypted,
    'message_type': messageType.name,
    'unread_count': unreadCount,
  };

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
