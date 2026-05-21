import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

class StatusService {
  final _db = Supabase.instance.client;
  final String _uid;
  StatusService(this._uid);

  Future<StatusModel> postTextStatus({required String text, String bgColor = '#075E54'}) async {
    final data = await _db.from(SupabaseConstants.statusesTable).insert({
      'user_id': _uid, 'text': text, 'type': 'text', 'bg_color': bgColor,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String(),
    }).select().single();
    return StatusModel.fromMap(data);
  }

  Future<StatusModel> postImageStatus(Uint8List bytes) async {
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from(SupabaseConstants.statusMediaBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    final url = _db.storage.from(SupabaseConstants.statusMediaBucket).getPublicUrl(path);
    final data = await _db.from(SupabaseConstants.statusesTable).insert({
      'user_id': _uid, 'content_url': url, 'type': 'image',
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String(),
    }).select().single();
    return StatusModel.fromMap(data);
  }

  Future<StatusModel> postVideoStatus(Uint8List bytes, String ext) async {
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mimeType = ext == 'mp4' ? 'video/mp4' : 'video/$ext';
    await _db.storage.from(SupabaseConstants.statusMediaBucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));
    final url = _db.storage.from(SupabaseConstants.statusMediaBucket).getPublicUrl(path);
    final data = await _db.from(SupabaseConstants.statusesTable).insert({
      'user_id': _uid, 'content_url': url, 'type': 'video',
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String(),
    }).select().single();
    return StatusModel.fromMap(data);
  }

  Future<List<StatusModel>> fetchAllStatuses() async {
    final data = await _db.from(SupabaseConstants.statusesTable)
        .select('*, user:user_id(*), views:status_views(*)')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return data.map<StatusModel>((m) {
      final status = StatusModel.fromMap(m);
      if (m['user'] != null) status.user = UserModel.fromMap(m['user']);
      if (m['views'] != null) {
        status.views = (m['views'] as List).map((v) => StatusViewModel.fromMap(v)).toList();
        status.viewedByMe = status.views.any((v) => v.viewerId == _uid);
      }
      return status;
    }).toList();
  }

  Future<List<StatusModel>> fetchMyStatuses() async {
    final data = await _db.from(SupabaseConstants.statusesTable)
        .select('*, views:status_views(*, viewer:viewer_id(*))')
        .eq('user_id', _uid)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return data.map<StatusModel>((m) {
      final status = StatusModel.fromMap(m);
      if (m['views'] != null) {
        status.views = (m['views'] as List).map((v) {
          final sv = StatusViewModel.fromMap(v);
          if (v['viewer'] != null) sv.viewer = UserModel.fromMap(v['viewer']);
          return sv;
        }).toList();
      }
      return status;
    }).toList();
  }

  Future<void> markViewed(String statusId) async {
    await _db.from(SupabaseConstants.statusViewsTable).upsert({
      'status_id': statusId, 'viewer_id': _uid,
    });
  }

  Future<void> deleteStatus(String statusId) async {
    await _db.from(SupabaseConstants.statusesTable)
        .delete().eq('id', statusId).eq('user_id', _uid);
  }
}
