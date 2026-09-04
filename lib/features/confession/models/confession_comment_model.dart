class ConfessionCommentModel {
  final String id;
  final String text;
  final bool isAnonymous;
  final bool isMine;
  final String authorName;
  final String authorPhoto;
  final DateTime createdAt;

  ConfessionCommentModel({
    required this.id,
    required this.text,
    this.isAnonymous = true,
    this.isMine = false,
    required this.authorName,
    required this.authorPhoto,
    required this.createdAt,
  });

  factory ConfessionCommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] ?? {};
    return ConfessionCommentModel(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['text'] ?? '',
      isAnonymous: json['isAnonymous'] ?? true,
      isMine: json['isMine'] ?? false,
      authorName: author['name'] ?? 'Anonymous Student',
      authorPhoto: author['profilePhoto'] ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=anon',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
