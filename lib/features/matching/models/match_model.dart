class MatchModel {
  final String id;
  final DateTime matchedAt;
  final String? conversationId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isOnline;
  final String userId;
  final String name;
  final String username;
  final String profilePhoto;
  final String college;
  final String course;
  final int year;

  MatchModel({
    required this.id,
    required this.matchedAt,
    this.conversationId,
    required this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePhoto,
    this.college = 'University',
    required this.course,
    required this.year,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] ?? {};
    return MatchModel(
      id: json['id'] ?? '',
      matchedAt: DateTime.tryParse(json['matchedAt'] ?? '') ?? DateTime.now(),
      conversationId: json['conversationId'],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.tryParse(json['lastMessageAt']) : null,
      unreadCount: json['unreadCount'] ?? 0,
      isOnline: json['isOnline'] == true || userData['isOnline'] == true,
      userId: userData['userId'] ?? userData['_id'] ?? userData['id'] ?? '',
      name: userData['name'] ?? 'Student',
      username: userData['username'] ?? '',
      profilePhoto: userData['profilePhoto'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
      college: userData['college'] ?? 'University',
      course: userData['course'] ?? '',
      year: userData['year'] is int ? userData['year'] : int.tryParse(userData['year']?.toString() ?? '1') ?? 1,
    );
  }
}
