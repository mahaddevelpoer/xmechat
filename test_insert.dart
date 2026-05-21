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

  final url = Uri.parse('$supabaseUrl/rest/v1/users');
  final req = await HttpClient().postUrl(url);
  req.headers.add('apikey', anonKey);
  req.headers.add('Authorization', 'Bearer $anonKey');
  req.headers.add('Content-Type', 'application/json');
  req.headers.add('Prefer', 'return=representation');

  final body = jsonEncode({
    'id': 'd0000000-0000-0000-0000-000000000000',
    'email': 'test@test.com',
    'name': 'Test',
  });

  req.write(body);

  final res = await req.close();
  final resBody = await res.transform(utf8.decoder).join();
  stdout.writeln('Status: ${res.statusCode}');
  stdout.writeln('Body: $resBody');
}
