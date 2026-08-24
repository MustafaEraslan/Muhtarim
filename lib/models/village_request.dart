class VillageRequest {
  const VillageRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.ownerName,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;
  final String ownerName;

  factory VillageRequest.fromJson(Map<String, dynamic> json) => VillageRequest(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'Diğer',
    status: json['status'] as String? ?? 'open',
    createdAt: DateTime.parse(json['created_at'] as String),
    ownerName:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Köy sakini',
  );
}
