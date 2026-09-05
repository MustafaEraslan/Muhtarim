import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/village_request.dart';
import '../models/work_post.dart';

class MuhtarimService {
  static const _postBucket = 'muhtarim-posts';
  SupabaseClient get _client => Supabase.instance.client;

  Future<AppUser> currentUser() async {
    final data = await _client.rpc(
      'muhtarim_current_app_user',
      params: {'p_app_id': AppConfig.appId},
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Announcement>> announcements() async {
    final rows = await _client
        .from('announcements')
        .select()
        .eq('app_id', AppConfig.appId)
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
      'app_id': AppConfig.appId,
      'title': title,
      'body': body,
      'type': type,
    });
  }

  Future<List<VillageRequest>> requests() async {
    final rows = await _client
        .from('requests')
        .select(
          '*, owner:village_profiles!requests_app_creator_fkey(full_name)',
        )
        .eq('app_id', AppConfig.appId)
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
      'app_id': AppConfig.appId,
      'title': title,
      'description': description,
      'category': category,
    });
  }

  Future<void> updateRequestStatus(String id, String status) async {
    await _client
        .from('requests')
        .update({'status': status})
        .eq('app_id', AppConfig.appId)
        .eq('id', id);
  }

  Future<List<WorkPost>> workPosts() async {
    final rows = await _client
        .from('work_posts')
        .select(
          '*, owner:village_profiles!work_posts_app_creator_fkey(full_name)',
        )
        .eq('app_id', AppConfig.appId)
        .order('occurred_at', ascending: false);

    return Future.wait(
      (rows as List).map((rawRow) async {
        final row = Map<String, dynamic>.from(rawRow as Map);
        row['image_url'] = await _client.storage
            .from(_postBucket)
            .createSignedUrl(row['image_path'] as String, 3600);
        return WorkPost.fromJson(row);
      }),
    );
  }

  Future<void> createWorkPost({
    required AppUser user,
    required String title,
    required String body,
    required String location,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    final safeExtension = switch (fileExtension.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      'heic' => 'heic',
      _ => 'jpg',
    };
    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final imagePath =
        '${AppConfig.appId}/${user.villageId}/'
        '${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    await _client.storage
        .from(_postBucket)
        .uploadBinary(
          imagePath,
          imageBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    try {
      await _client.from('work_posts').insert({
        'app_id': AppConfig.appId,
        'title': title,
        'body': body,
        'location': location,
        'image_path': imagePath,
      });
    } catch (_) {
      await _client.storage.from(_postBucket).remove([imagePath]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> members() async {
    final rows = await _client.rpc(
      'muhtarim_village_members_for_current_user',
      params: {'p_app_id': AppConfig.appId},
    );
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> signOut() => _client.auth.signOut();
}
