import 'dart:convert';
import 'dart:io';

void main() async {
  const supabaseUrl = 'https://wdislbdftnwmaexqtfmn.supabase.co';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];
  if (anonKey == null || anonKey.isEmpty) {
    stderr.writeln('Set SUPABASE_ANON_KEY before running this script.');
    exitCode = 64;
    return;
  }

  final url = Uri.parse('$supabaseUrl/rest/v1/users?select=*');
  final req = await HttpClient().getUrl(url);
  req.headers.add('apikey', anonKey);
  req.headers.add('Authorization', 'Bearer $anonKey');

  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  stdout.writeln('Status: ${res.statusCode}');
  stdout.writeln('Body: $body');
}
