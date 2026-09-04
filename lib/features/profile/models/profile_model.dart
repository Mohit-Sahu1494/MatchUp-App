class ProfileModel {
  final String id;
  final String userId;
  final String name;
  final String username;
  final String profilePhoto;
  final List<String> photos;
  final List<String> videos;
  final String bio;
  final String category;
  final String college;
  final String course;
  final String branch;
  final int year;
  final int age;
  final List<String> interests;
  final List<String> hobbies;
  final List<String> relationshipPreferences;
  final String themePreference;
  final double height;
  final String gender;
  final String location;
  final Map<String, dynamic> socialLinks;
  final int compatibilityScore;
  final String compatibilityLevel;
  final String recommendationType;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.photos,
    required this.videos,
    required this.bio,
    required this.category,
    this.college = 'University',
    required this.course,
    required this.branch,
    required this.year,
    this.age = 20,
    required this.interests,
    this.hobbies = const [],
    this.relationshipPreferences = const ['Dating'],
    this.themePreference = 'system',
    required this.height,
    required this.gender,
    required this.location,
    required this.socialLinks,
    this.compatibilityScore = 0,
    this.compatibilityLevel = 'MEDIUM',
    this.recommendationType = 'compatibility',
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final score = json['compatibilityScore'] is int
        ? json['compatibilityScore']
        : int.tryParse(json['compatibilityScore']?.toString() ?? '0') ?? 0;

    String level = json['compatibilityLevel'] ?? '';
    if (level.isEmpty) {
      if (score < 30) {
        level = 'LOW';
      } else if (score < 60) {
        level = 'MEDIUM';
      } else {
        level = 'HIGH';
      }
    }

    return ProfileModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] is Map ? (json['userId']['_id'] ?? '') : (json['userId'] ?? ''),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      profilePhoto: json['profilePhoto'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      bio: json['bio'] ?? '',
      category: json['category'] ?? '',
      college: json['college'] ?? 'University',
      course: json['course'] ?? '',
      branch: json['branch'] ?? '',
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? '1') ?? 1,
      age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? '20') ?? 20,
      interests: List<String>.from(json['interests'] ?? []),
      hobbies: List<String>.from(json['hobbies'] ?? []),
      relationshipPreferences: List<String>.from(json['relationshipPreferences'] ?? ['Dating']),
      themePreference: json['themePreference'] ?? 'system',
      height: (json['height'] as num?)?.toDouble() ?? 170.0,
      gender: json['gender'] ?? 'Prefer not to say',
      location: json['location'] ?? 'Campus',
      socialLinks: json['socialLinks'] is Map ? Map<String, dynamic>.from(json['socialLinks']) : {},
      compatibilityScore: score,
      compatibilityLevel: level,
      recommendationType: json['recommendationType'] ?? 'compatibility',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'profilePhoto': profilePhoto,
      'bio': bio,
      'college': college,
      'course': course,
      'branch': branch,
      'year': year,
      'age': age,
      'interests': interests,
      'hobbies': hobbies,
      'relationshipPreferences': relationshipPreferences,
      'themePreference': themePreference,
      'height': height,
      'gender': gender,
      'location': location,
    };
  }
}
