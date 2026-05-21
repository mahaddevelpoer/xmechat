import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['RESEND_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set RESEND_API_KEY before running this script.');
    exitCode = 64;
    return;
  }

  final url = Uri.parse('https://api.resend.com/emails');
  final req = await HttpClient().postUrl(url);
  req.headers.add('Authorization', 'Bearer $apiKey');
  req.headers.add('Content-Type', 'application/json');

  final body = jsonEncode({
    'from': 'XmeChat <onboarding@resend.dev>',
    'to': 'mahadb847@gmail.com',
    'subject': 'Your XmeChat Verification Code',
    'html': '<p>Your OTP is 123456</p>',
  });

  req.write(body);

  final res = await req.close();
  final resBody = await res.transform(utf8.decoder).join();
  stdout.writeln('Status: ${res.statusCode}');
  stdout.writeln('Body: $resBody');
}
