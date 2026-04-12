class Group {
  final String id;
  final String name;
  final String description;
  final String userId;
  final int reelCount;
  final String createdAt;

  Group({
    required this.id,
    required this.name,
    this.description = '',
    required this.userId,
    this.reelCount = 0,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      userId: json['userId'] ?? '',
      reelCount: json['reelCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
    );
  }
}
