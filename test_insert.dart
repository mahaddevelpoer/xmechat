import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://wdislbdftnwmaexqtfmn.supabase.co/rest/v1/users');
  final req = await HttpClient().postUrl(url);
  req.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndkaXNsYmRmdG53bWFleHF0Zm1uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1ODY0MzksImV4cCI6MjA4NTE2MjQzOX0.hSUYRs4scWmUNZGK0slHeX9t--Of5CZclAhoCRbcXmc');
  req.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndkaXNsYmRmdG53bWFleHF0Zm1uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1ODY0MzksImV4cCI6MjA4NTE2MjQzOX0.hSUYRs4scWmUNZGK0slHeX9t--Of5CZclAhoCRbcXmc');
  req.headers.add('Content-Type', 'application/json');
  req.headers.add('Prefer', 'return=representation');
  
  final body = jsonEncode({
    'id': 'd0000000-0000-0000-0000-000000000000',
    'email': 'test@test.com',
    'name': 'Test'
  });
  
  req.write(body);
  
  final res = await req.close();
  final resBody = await res.transform(utf8.decoder).join();
  print('Status: ${res.statusCode}');
  print('Body: $resBody');
}
