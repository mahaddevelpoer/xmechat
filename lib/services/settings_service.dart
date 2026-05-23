import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final _db = Supabase.instance.client;
  final String _uid;

  SettingsService(this._uid);

  Future<Map<String, dynamic>> fetchAll() async {
    final data = await _db
        .from('user_settings')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  Future<void> save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    else if (value is double) await prefs.setDouble(key, value);
    else if (value is int) await prefs.setInt(key, value);
    else if (value is String) await prefs.setString(key, value);

    await _db.from('user_settings').upsert({
      'user_id': _uid,
      key: value,
    }, onConflict: 'user_id');
  }

  Future<void> saveBatch(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is bool) await prefs.setBool(key, value);
      else if (value is double) await prefs.setDouble(key, value);
      else if (value is int) await prefs.setInt(key, value);
      else if (value is String) await prefs.setString(key, value);
    }
    await _db.from('user_settings').upsert({
      'user_id': _uid,
      ...settings,
    }, onConflict: 'user_id');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (!key.endsWith('_rsa_private_key') && !key.endsWith('_rsa_public_key')) {
        await prefs.remove(key);
      }
    }
    await _db.from('user_settings').delete().eq('user_id', _uid);
  }
}
