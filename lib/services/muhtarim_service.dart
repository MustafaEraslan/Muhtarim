import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/village_request.dart';

class MuhtarimService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AppUser> currentUser() async {
    final data = await _client.rpc('muhtarim_current_app_user');
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Announcement>> announcements() async {
    final rows = await _client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => Announcement.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String type,
  }) async {
    await _client.from('announcements').insert({
      'title': title,
      'body': body,
      'type': type,
    });
  }

  Future<List<VillageRequest>> requests() async {
    final rows = await _client
        .from('requests')
        .select('*, village_profiles!requests_created_by_fkey(full_name)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              VillageRequest.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> createRequest({
    required String title,
    required String description,
    required String category,
  }) async {
    await _client.from('requests').insert({
      'title': title,
      'description': description,
      'category': category,
    });
  }

  Future<void> updateRequestStatus(String id, String status) async {
    await _client.from('requests').update({'status': status}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> members() async {
    final rows = await _client.rpc('muhtarim_village_members_for_current_user');
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> signOut() => _client.auth.signOut();
}
