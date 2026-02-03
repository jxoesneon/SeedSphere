import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:router/task_service.dart';
import 'package:test/test.dart';

void main() {
  group('TaskService', () {
    late TaskService service;
    const secret = 'test-secret-123';

    setUp(() {
      service = TaskService(secret);
    });

    test('requestTask generates valid JWT', () {
      final payload = {'foo': 'bar'};
      final token = service.requestTask('echo', payload);

      expect(token, isNotEmpty);

      // Verify manually
      final jwt = JWT.verify(token, SecretKey(secret));
      expect(jwt.payload['task_type'], 'echo');
      expect(jwt.payload['payload']['foo'], 'bar');
      expect(jwt.payload['task_id'], isNotNull);
    });

    test('verifyResult returns payload for valid token', () {
      final token = service.requestTask('test', {'a': 1});
      final result = service.verifyResult(token);

      expect(result, isNotNull);
      expect(result!['task_type'], 'test');
      expect(result['payload']['a'], 1);
    });

    test('verifyResult returns null for invalid signature', () {
      // Sign with wrong secret
      final jwt = JWT({'typ': 'task'});
      final token = jwt.sign(SecretKey('wrong-secret'));

      final result = service.verifyResult(token);
      expect(result, isNull);
    });

    test('verifyResult returns null for expired token', () async {
      // Create a token that expires instantly (or 1s ago)
      // Since we can't mock time in JWT library easily without a custom clock,
      // we'll explicitly generate a token with past exp claim if possible, or
      // rely on library behavior.
      // dart_jsonwebtoken usually uses DateTime.now().
      // Workaround: Manually construct a JWT with 'exp' in the past.
      final jwt = JWT({
        'typ': 'task',
        // 5 seconds ago
        'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 5,
      });
      // We must sign it without expiresIn param so it doesn't overwrite our exp claim?
      // Library: if expiresIn is set, it adds it. If we manually put exp, hopefully it respects it.
      // Actually the library verifies 'exp'.

      final token = jwt.sign(SecretKey(secret));
      // Wait a tiny bit just in case
      await Future.delayed(const Duration(milliseconds: 100));

      final result = service.verifyResult(token);
      expect(result, isNull);
    });

    test('requestTask throws if secret is empty', () {
      final badService = TaskService('');
      expect(() => badService.requestTask('fail', {}), throwsException);
    });
  });
}
