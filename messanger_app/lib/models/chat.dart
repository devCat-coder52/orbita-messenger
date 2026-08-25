class Chat {
  int? chatId;
  final int userId;
  final String userName;
  final String? avatarUrl;
  bool? isOnline;
  int? messageSender;
  String? messageTime;
  String? messageText;
  int unreadCount;

  Chat({
    this.chatId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.isOnline,
    this.messageSender,
    this.messageTime,
    this.messageText,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chat_id'],
      userId: json['user_id'],
      userName: json['user_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'],
      messageSender: json['message_sender'],
      messageTime: json['message_time'] /*!= null
          ? DateTime.parse(json['message_time'])
          : null*/,
      messageText: json['message_text'],
      unreadCount: json['unread_count'],
    );
  }
}
