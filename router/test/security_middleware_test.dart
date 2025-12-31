import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:router/security_middleware.dart';

void main() {
  group('SecurityMiddleware', () {
    late Handler handler;
    final secret = 'test-secret';

    setUp(() {
      Future<String?> getSecret(String gId, String sId) async {
        if (gId == 'valid-gardener' && sId == 'valid-seedling') return secret;
        return null;
      }

      final middleware = securityMiddleware(getSecret);
      handler = middleware((Request req) => Response.ok('ok'));
    });

    Map<String, String> generateHeaders({
      String gardenerId = 'valid-gardener',
      String seedlingId = 'valid-seedling',
      String body = '',
      String path = 'api/test',
      String method = 'POST',
      int? timestamp,
      String? nonce,
      String? overrideSig,
    }) {
      final ts = (timestamp ?? DateTime.now().millisecondsSinceEpoch)
          .toString();
      final n = nonce ?? DateTime.now().microsecondsSinceEpoch.toString();
      final bodyHash = sha256.convert(utf8.encode(body)).toString();

      final canonical = [
        ts,
        n,
        method,
        path,
        '', // query
        bodyHash,
      ].join('\n');

      final hmac = Hmac(sha256, utf8.encode(secret));
      final sig = base64Url
          .encode(hmac.convert(utf8.encode(canonical)).bytes)
          .replaceAll('=', '');

      return {
        'X-SeedSphere-G': gardenerId,
        'X-SeedSphere-Id': seedlingId,
        'X-SeedSphere-Ts': ts,
        'X-SeedSphere-Nonce': n,
        'X-SeedSphere-Sig': overrideSig ?? sig,
      };
    }

    test('allows valid signature', () async {
      final headers = generateHeaders();
      final req = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      final res = await handler(req);
      expect(res.statusCode, 200);
    });

    test('blocks missing headers', () async {
      final req = Request('POST', Uri.parse('http://localhost/api/test'));
      final res = await handler(req);
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('missing_security_headers'));
    });

    test('blocks clock skew', () async {
      final oldTs = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      final headers = generateHeaders(timestamp: oldTs);
      final req = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      final res = await handler(req);
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('clock_skew_too_large'));
    });

    test('blocks invalid signature', () async {
      final headers = generateHeaders(overrideSig: 'invalid-sig');
      final req = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      final res = await handler(req);
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('invalid_signature'));
    });

    test('blocks unauthorized device', () async {
      final headers = generateHeaders(gardenerId: 'invalid');
      // Note: calculate sig with valid secret but server won't find secret, so standard flow checks secret first
      // Actually helper uses 'test-secret', but server returns null for invalid gardener

      final req = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      final res = await handler(req);
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('unauthorized_device'));
    });

    test('blocks nonce reuse', () async {
      final headers = generateHeaders(nonce: 'unique-1');
      final req1 = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      await handler(req1);

      final req2 = Request(
        'POST',
        Uri.parse('http://localhost/api/test'),
        headers: headers,
      );
      final res = await handler(req2);
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('nonce_reused'));
    });
  });
}
