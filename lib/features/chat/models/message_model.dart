class ReplyToModel {
  final String id;
  final String senderId;
  final String text;

  ReplyToModel({
    required this.id,
    required this.senderId,
    required this.text,
  });

  factory ReplyToModel.fromJson(Map<String, dynamic> json) {
    return ReplyToModel(
      id: json['id'] ?? json['_id'] ?? '',
      senderId: json['senderId'] is Map ? (json['senderId']['_id'] ?? '') : (json['senderId'] ?? ''),
      text: json['text'] ?? '',
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String mediaUrl;
  final String mediaType;
  final Map<String, dynamic>? giftData;
  final ReplyToModel? replyTo;
  final bool isEdited;
  final bool isDeletedForEveryone;
  final bool isMine;
  final String status;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    this.giftData,
    this.replyTo,
    this.isEdited = false,
    this.isDeletedForEveryone = false,
    this.isMine = false,
    required this.status,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sender = json['senderId'] is Map ? (json['senderId']['_id'] ?? '') : (json['senderId'] ?? '');
    final bool mine = json['isMine'] == true || (currentUserId != null && currentUserId.isNotEmpty && sender.toString() == currentUserId.toString());

    ReplyToModel? reply;
    if (json['replyTo'] != null && json['replyTo'] is Map) {
      reply = ReplyToModel.fromJson(Map<String, dynamic>.from(json['replyTo']));
    }

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: sender.toString(),
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'text',
      giftData: json['giftData'],
      replyTo: reply,
      isEdited: json['isEdited'] == true,
      isDeletedForEveryone: json['isDeletedForEveryone'] == true,
      isMine: mine,
      status: json['status'] ?? 'sent',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  MessageModel copyWith({
    String? text,
    bool? isEdited,
    bool? isDeletedForEveryone,
    String? status,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text ?? this.text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      giftData: giftData,
      replyTo: replyTo,
      isEdited: isEdited ?? this.isEdited,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      isMine: isMine,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class ConversationModel {
  final String id;
  final String recipientId;
  final String recipientName;
  final String recipientPhoto;
  final bool isOnline;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhoto,
    required this.isOnline,
    required this.lastMessageText,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final recip = json['recipient'] ?? {};
    return ConversationModel(
      id: json['id'] ?? '',
      recipientId: recip['id'] ?? '',
      recipientName: recip['name'] ?? 'Student',
      recipientPhoto: recip['profilePhoto'] ?? '',
      isOnline: recip['isOnline'] ?? false,
      lastMessageText: json['lastMessageText'] ?? '',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] ?? '') ?? DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
