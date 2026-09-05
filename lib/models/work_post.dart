class WorkPost {
  const WorkPost({
    required this.id,
    required this.title,
    required this.body,
    required this.imagePath,
    required this.imageUrl,
    required this.location,
    required this.ownerName,
    required this.isDemo,
    required this.occurredAt,
  });

  final String id;
  final String title;
  final String body;
  final String imagePath;
  final String imageUrl;
  final String location;
  final String ownerName;
  final bool isDemo;
  final DateTime occurredAt;

  factory WorkPost.fromJson(Map<String, dynamic> json) => WorkPost(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    imagePath: json['image_path'] as String,
    imageUrl: json['image_url'] as String,
    location: json['location'] as String? ?? '',
    ownerName:
        (json['owner'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Muhtarlık',
    isDemo: json['is_demo'] as bool? ?? false,
    occurredAt: DateTime.parse(json['occurred_at'] as String),
  );
}
