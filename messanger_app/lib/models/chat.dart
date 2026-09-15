class Chat {
  int? chatId;
  final int userId;
  final String userName;
  final String? avatarUrl;
  bool? isOnline;
  bool isPinned;
  int? messageSender;
  int? messageTime;
  String? messageText;
  bool? messageIsEncrypted;
  String messageType;
  int unreadCount;

  Chat({
    this.chatId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.isOnline,
    this.isPinned = false,
    this.messageSender,
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
      isPinned: json['is_pinned'],
      messageSender: json['message_sender'],
      messageTime: json['message_time'] != null
          ? int.parse(json['message_time'])
          : null,
      messageText: json['message_text'],
      messageIsEncrypted: json['message_is_encrypted'],
      messageType: json['message_type'],
      unreadCount: json['unread_count'],
    );
  }
}
