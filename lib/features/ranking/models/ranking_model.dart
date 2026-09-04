class RankingItemModel {
  final int rank;
  final String userId;
  final int totalScore;
  final int giftPoints;
  final int activityPoints;
  final String name;
  final String username;
  final String profilePhoto;
  final String course;
  final int year;

  RankingItemModel({
    required this.rank,
    required this.userId,
    required this.totalScore,
    required this.giftPoints,
    required this.activityPoints,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.course,
    required this.year,
  });

  factory RankingItemModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    return RankingItemModel(
      rank: json['rank'] ?? 0,
      userId: json['userId'] ?? '',
      totalScore: json['totalScore'] ?? 0,
      giftPoints: json['giftPoints'] ?? 0,
      activityPoints: json['activityPoints'] ?? 0,
      name: user['name'] ?? 'Student',
      username: user['username'] ?? '',
      profilePhoto: user['profilePhoto'] ?? '',
      course: user['course'] ?? '',
      year: user['year'] ?? 1,
    );
  }
}
