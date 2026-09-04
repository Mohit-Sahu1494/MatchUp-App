class ConfessionModel {
  final String id;
  final String text;
  final String mediaUrl;
  final bool isAnonymous;
  final int likesCount;
  final int commentsCount;
  final String category;
  final bool hasLiked;
  final bool isMine;
  final String authorName;
  final String authorPhoto;
  final DateTime createdAt;

  ConfessionModel({
    required this.id,
    required this.text,
    required this.mediaUrl,
    required this.isAnonymous,
    required this.likesCount,
    required this.commentsCount,
    required this.category,
    required this.hasLiked,
    required this.isMine,
    required this.authorName,
    required this.authorPhoto,
    required this.createdAt,
  });

  factory ConfessionModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] ?? {};
    return ConfessionModel(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'] ?? '',
      isAnonymous: json['isAnonymous'] ?? true,
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      category: json['category'] ?? 'General',
      hasLiked: json['hasLiked'] ?? false,
      isMine: json['isMine'] ?? false,
      authorName: author['name'] ?? 'Anonymous Student',
      authorPhoto: author['profilePhoto'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
