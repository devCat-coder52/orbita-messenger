import 'member.dart';

enum MessageStatus {
  sending('sending'),
  sent('sent'),
  read('read'),
  error('error'),
  forwarding('forwarding');

  const MessageStatus(this.wire);
  final String wire;

  static MessageStatus parse(Object? value) {
    return MessageStatus.values.firstWhere(
      (s) => s.wire == value,
      orElse: () => MessageStatus.sent,
    );
  }
}

enum MessageType { text, image, file, voice }

class Message {
  final int? id;
  final Member sender;
  final String content;
  final int timeCreate;
  final MessageStatus status;
  final bool isEdited;
  final bool isEncrypted;

  final Map<String, dynamic>? reply;

  final Map<String, dynamic>? forward;

  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? voiceUrl;
  final int? voiceDurationSeconds;

  bool isSelected;
  bool isTemp;

  Message({
    this.id,
    required this.sender,
    this.content = '',
    required this.timeCreate,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.isEncrypted = false,
    this.reply,
    this.forward,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.voiceUrl,
    this.voiceDurationSeconds,
    this.isSelected = false,
    this.isTemp = false,
  });

  MessageType get type {
    if (hasImage) return MessageType.image;
    if (hasFile) return MessageType.file;
    if (hasVoice) return MessageType.voice;
    return MessageType.text;
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;
  bool get isForwarding => status == MessageStatus.forwarding;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(timeCreate);

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSender = json['sender'];
    final sender = rawSender is Map
        ? Member.fromMap(Map<String, dynamic>.from(rawSender))
        : Member.anonymous();

    return Message(
      id: _asInt(json['id']),
      sender: sender,
      content: (json['content'] ?? '').toString(),
      timeCreate: _asInt(json['time_create']) ?? 0,
      status: MessageStatus.parse(json['status']),
      isEdited: json['is_edited'] == true,
      isEncrypted: json['is_encrypted'] == true,
      reply: _asMap(json['reply']),
      forward: _asMap(json['forward']),
      imageUrl: json['image_url']?.toString(),
      fileUrl: json['file_url']?.toString(),
      fileName: json['file_name']?.toString(),
      fileSize: _asInt(json['file_size']),
      voiceUrl: json['voice_url']?.toString(),
      voiceDurationSeconds: _asInt(json['voice_duration']),
      isSelected: json['is_selected'] == true,
      isTemp: json['is_temp'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender.toMap(),
    'content': content,
    'time_create': timeCreate.toString(),
    'status': status.wire,
    'is_edited': isEdited,
    'is_encrypted': isEncrypted,
    'reply': reply,
    'forward': forward,
    'image_url': imageUrl,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_size': fileSize,
    'voice_url': voiceUrl,
    'voice_duration': voiceDurationSeconds?.toString(),
    'is_selected': isSelected,
    'is_temp': isTemp,
  };

  Message copyWith({
    int? id,
    Member? sender,
    String? content,
    int? timeCreate,
    MessageStatus? status,
    bool? isEdited,
    bool? isEncrypted,
    Map<String, dynamic>? reply,
    Map<String, dynamic>? forward,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? voiceUrl,
    int? voiceDurationSeconds,
    bool? isSelected,
    bool? isTemp,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timeCreate: timeCreate ?? this.timeCreate,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      reply: reply ?? this.reply,
      forward: forward ?? this.forward,
      imageUrl: imageUrl ?? this.imageUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      isSelected: isSelected ?? this.isSelected,
      isTemp: isTemp ?? this.isTemp,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
