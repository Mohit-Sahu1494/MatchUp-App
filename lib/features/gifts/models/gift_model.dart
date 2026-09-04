class GiftModel {
  final String code;
  final String name;
  final String icon;
  final int pointValue;

  GiftModel({
    required this.code,
    required this.name,
    required this.icon,
    required this.pointValue,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '🎁',
      pointValue: json['pointValue'] ?? 10,
    );
  }
}
