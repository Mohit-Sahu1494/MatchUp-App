DateTime parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value.toLocal();
  if (value is int) {
    if (value < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  }
  final str = value.toString();
  final intVal = int.tryParse(str);
  if (intVal != null && str.length >= 10) {
    if (intVal < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intVal * 1000).toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(intVal).toLocal();
  }
  final parsed = DateTime.tryParse(str);
  if (parsed != null) {
    return parsed.toLocal();
  }
  return DateTime.now();
}

class ReplyToModel {
  final String id;
  final String senderId;
  final String text;
  final String mediaType;
  final bool isDeletedForEveryone;

  ReplyToModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.mediaType = 'text',
    this.isDeletedForEveryone = false,
  });

  factory ReplyToModel.fromJson(Map<String, dynamic> json) {
    final sender = json['senderId'] is Map ? (json['senderId']['_id'] ?? '') : (json['senderId'] ?? '');
    final isDeleted = json['isDeletedForEveryone'] == true;
    return ReplyToModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: sender.toString(),
      text: isDeleted ? 'This message was deleted' : (json['text'] ?? ''),
      mediaType: (json['mediaType'] ?? 'text').toString(),
      isDeletedForEveryone: isDeleted,
    );
  }
}

class MessageReaction {
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: (json['userId'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      createdAt: parseDateTime(json['createdAt']),
    );
  }
}

class ForwardedFromModel {
  final String? messageId;
  final String? originalSenderId;
  final String originalSenderName;

  ForwardedFromModel({
    this.messageId,
    this.originalSenderId,
    this.originalSenderName = '',
  });

  factory ForwardedFromModel.fromJson(Map<String, dynamic> json) {
    return ForwardedFromModel(
      messageId: json['messageId']?.toString(),
      originalSenderId: json['originalSenderId']?.toString(),
      originalSenderName: (json['originalSenderName'] ?? '').toString(),
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
  final String thumbnailUrl;
  final int duration;
  final String fileName;
  final Map<String, dynamic>? giftData;
  final ReplyToModel? replyTo;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeletedForEveryone;
  final DateTime? deletedAt;
  final bool isMine;
  final String status;
  final DateTime createdAt;
  final List<MessageReaction> reactions;
  final Map<String, int> reactionsSummary;
  final String? myReaction;
  final bool isForwarded;
  final ForwardedFromModel? forwardedFrom;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl = '',
    this.duration = 0,
    this.fileName = '',
    this.giftData,
    this.replyTo,
    this.isEdited = false,
    this.editedAt,
    this.isDeletedForEveryone = false,
    this.deletedAt,
    this.isMine = false,
    required this.status,
    required this.createdAt,
    this.reactions = const [],
    this.reactionsSummary = const {},
    this.myReaction,
    this.isForwarded = false,
    this.forwardedFrom,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sender = json['senderId'] is Map ? (json['senderId']['_id'] ?? '') : (json['senderId'] ?? '');
    final String senderStr = sender.toString();
    // Prioritize actual senderId vs currentUserId comparison so incoming messages are never marked isMine
    final bool mine = (currentUserId != null && currentUserId.isNotEmpty)
        ? (senderStr == currentUserId.toString())
        : (json['isMine'] == true);

    ReplyToModel? reply;
    if (json['replyTo'] != null && json['replyTo'] is Map) {
      reply = ReplyToModel.fromJson(Map<String, dynamic>.from(json['replyTo']));
    }

    final msgId = json['messageId'] ?? json['_id'] ?? json['id'] ?? '';
    final mediaType = json['mediaType'] ?? json['messageType'] ?? 'text';

    // Parse reactions
    final List<MessageReaction> parsedReactions = [];
    if (json['reactions'] is List) {
      for (final r in json['reactions']) {
        if (r is Map) {
          parsedReactions.add(MessageReaction.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    // Parse reactionsSummary
    final Map<String, int> parsedSummary = {};
    if (json['reactionsSummary'] is Map) {
      (json['reactionsSummary'] as Map).forEach((k, v) {
        parsedSummary[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    } else {
      // Build summary from parsedReactions if not in json
      for (final r in parsedReactions) {
        parsedSummary[r.emoji] = (parsedSummary[r.emoji] ?? 0) + 1;
      }
    }

    // Determine myReaction
    String? myReact = json['myReaction']?.toString();
    if (myReact == null && currentUserId != null) {
      for (final r in parsedReactions) {
        if (r.userId == currentUserId.toString()) {
          myReact = r.emoji;
          break;
        }
      }
    }

    // Parse forward metadata
    final isFwd = json['isForwarded'] == true;
    ForwardedFromModel? fwdFrom;
    if (json['forwardedFrom'] != null && json['forwardedFrom'] is Map) {
      fwdFrom = ForwardedFromModel.fromJson(Map<String, dynamic>.from(json['forwardedFrom']));
    }

    return MessageModel(
      id: msgId.toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: senderStr,
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: mediaType.toString(),
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      duration: json['duration'] is int ? json['duration'] : (int.tryParse(json['duration']?.toString() ?? '') ?? 0),
      fileName: json['fileName'] ?? '',
      giftData: json['giftData'],
      replyTo: reply,
      isEdited: json['isEdited'] == true,
      editedAt: json['editedAt'] != null ? parseDateTime(json['editedAt']) : null,
      isDeletedForEveryone: json['isDeletedForEveryone'] == true,
      deletedAt: json['deletedAt'] != null ? parseDateTime(json['deletedAt']) : null,
      isMine: mine,
      status: json['status'] ?? 'sent',
      createdAt: parseDateTime(json['createdAt']),
      reactions: parsedReactions,
      reactionsSummary: parsedSummary,
      myReaction: myReact,
      isForwarded: isFwd,
      forwardedFrom: fwdFrom,
    );
  }

  MessageModel copyWith({
    String? text,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeletedForEveryone,
    DateTime? deletedAt,
    String? status,
    String? mediaUrl,
    String? mediaType,
    String? thumbnailUrl,
    List<MessageReaction>? reactions,
    Map<String, int>? reactionsSummary,
    String? myReaction,
    bool? isForwarded,
    ForwardedFromModel? forwardedFrom,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration,
      fileName: fileName,
      giftData: giftData,
      replyTo: replyTo,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedAt: deletedAt ?? this.deletedAt,
      isMine: isMine,
      status: status ?? this.status,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      reactionsSummary: reactionsSummary ?? this.reactionsSummary,
      myReaction: myReaction ?? this.myReaction,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
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
      lastMessageAt: parseDateTime(json['lastMessageAt']),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
