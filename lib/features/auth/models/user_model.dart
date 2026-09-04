class UserModel {
  final String id;
  final String email;
  final String role;
  final bool isVerified;
  final int credits;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.isVerified,
    required this.credits,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      isVerified: json['isVerified'] ?? false,
      credits: json['credits'] ?? 100,
    );
  }
}
