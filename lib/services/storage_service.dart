import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final supabase = Supabase.instance.client;

  Future<String> uploadImage(Uint8List bytes) async {
    final name = DateTime.now().millisecondsSinceEpoch.toString();

    await supabase.storage
        .from('chat-images')
        .uploadBinary(name, bytes);

    return supabase.storage.from('chat-images').getPublicUrl(name);
  }

  Future<String> uploadAudio(Uint8List bytes) async {
    final name = DateTime.now().millisecondsSinceEpoch.toString();

    await supabase.storage
        .from('audio')
        .uploadBinary(name, bytes);

    return supabase.storage.from('audio').getPublicUrl(name);
  }

  Future<String> uploadProfile(Uint8List bytes) async {
    final name = DateTime.now().millisecondsSinceEpoch.toString();

    await supabase.storage
        .from('profiles')
        .uploadBinary(name, bytes);

    return supabase.storage.from('profiles').getPublicUrl(name);
  }
}
