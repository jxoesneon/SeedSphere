import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('--- Task System Verification ---');
  final router = 'http://127.0.0.1:8080';

  // 1. Request Task
  print('1. Requesting task...');
  final reqRes = await http.post(Uri.parse('$router/api/tasks/request'));
  print('Request Status: ${reqRes.statusCode}');

  if (reqRes.statusCode != 200) {
    print('Failed to request task: ${reqRes.body}');
    exit(1);
  }

  final token = jsonDecode(reqRes.body)['task_token'];
  print('Token: ${token.substring(0, 20)}...');

  // 2. Submit Result
  print('2. Submitting result...');
  final resRes = await http.post(
    Uri.parse('$router/api/tasks/result'),
    body: jsonEncode({
      'token': token,
      'result': {'status': 'success', 'data': 'verified_by_script'},
    }),
  );

  print('Result Status: ${resRes.statusCode}');
  print('Result Body: ${resRes.body}');

  if (resRes.statusCode == 200) {
    print('✅ Task System Verified.');
  } else {
    print('❌ Task Submission Failed.');
    exit(1);
  }
}
