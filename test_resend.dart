import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://api.resend.com/emails');
  final req = await HttpClient().postUrl(url);
  req.headers.add('Authorization', 'Bearer re_cbgvSdPz_Eh34UWepA1qn9GcE232g44kp');
  req.headers.add('Content-Type', 'application/json');
  
  final body = jsonEncode({
    'from': 'XmeChat <onboarding@resend.dev>',
    'to': 'mahadb847@gmail.com',
    'subject': 'Your XmeChat Verification Code',
    'html': '<p>Your OTP is 123456</p>'
  });
  
  req.write(body);
  
  final res = await req.close();
  final resBody = await res.transform(utf8.decoder).join();
  print('Status: ${res.statusCode}');
  print('Body: $resBody');
}
