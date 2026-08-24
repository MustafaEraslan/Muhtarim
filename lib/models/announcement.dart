class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    type: json['type'] as String? ?? 'Genel',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
