class LikeModel {
  final String id;
  final String targetUserId;
  final bool isMatched;
  final String? conversationId;
  final int compatibilityScore;
  final String compatibilityLevel;
  final DateTime likedAt;
  final String name;
  final String username;
  final String profilePhoto;
  final String college;
  final String course;
  final int year;
  final String bio;
  final List<String> relationshipPreferences;
  final bool isOnline;

  LikeModel({
    required this.id,
    required this.targetUserId,
    required this.isMatched,
    this.conversationId,
    required this.compatibilityScore,
    required this.compatibilityLevel,
    required this.likedAt,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.college,
    required this.course,
    required this.year,
    required this.bio,
    required this.relationshipPreferences,
    this.isOnline = false,
  });

  factory LikeModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] ?? {};
    final score = json['compatibilityScore'] is int
        ? json['compatibilityScore']
        : int.tryParse(json['compatibilityScore']?.toString() ?? '50') ?? 50;

    return LikeModel(
      id: json['id'] ?? '',
      targetUserId: json['targetUserId'] ?? profile['userId'] ?? profile['_id'] ?? '',
      isMatched: json['isMatched'] == true,
      conversationId: json['conversationId'],
      compatibilityScore: score,
      compatibilityLevel: json['compatibilityLevel'] ?? (score >= 60 ? 'HIGH' : (score >= 30 ? 'MEDIUM' : 'LOW')),
      likedAt: DateTime.tryParse(json['likedAt'] ?? '') ?? DateTime.now(),
      name: profile['name'] ?? 'Student',
      username: profile['username'] ?? '',
      profilePhoto: profile['profilePhoto'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
      college: profile['college'] ?? 'University',
      course: profile['course'] ?? '',
      year: profile['year'] is int ? profile['year'] : int.tryParse(profile['year']?.toString() ?? '1') ?? 1,
      bio: profile['bio'] ?? '',
      relationshipPreferences: List<String>.from(profile['relationshipPreferences'] ?? ['Dating']),
      isOnline: profile['isOnline'] == true,
    );
  }
}
