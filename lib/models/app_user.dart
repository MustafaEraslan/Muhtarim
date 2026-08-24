class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.villageId,
    required this.villageName,
    required this.joinCode,
  });

  final String id;
  final String fullName;
  final String role;
  final String villageId;
  final String villageName;
  final String joinCode;

  bool get isMukhtar => role == 'mukhtar';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? 'Kullanıcı',
    role: json['role'] as String? ?? 'villager',
    villageId: json['village_id'] as String,
    villageName: json['village_name'] as String? ?? 'Köyüm',
    joinCode: json['join_code'] as String? ?? '',
  );
}
