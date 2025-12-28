import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

/// Middleware for HMAC signature verification and replay protection.
Middleware securityMiddleware(
  Future<String?> Function(String gardenerId, String seedlingId) getSecret,
) {
  final nonceStore = <String, DateTime>{};

  return (Handler innerHandler) {
    return (Request request) async {
      final sig = request.headers['X-SeedSphere-Sig'];
      final tsStr = request.headers['X-SeedSphere-Ts'];
      final nonce = request.headers['X-SeedSphere-Nonce'];
      final gardenerId = request.headers['X-SeedSphere-G'];
      final seedlingId = request.headers['X-SeedSphere-Id'];

      if (sig == null ||
          tsStr == null ||
          nonce == null ||
          gardenerId == null ||
          seedlingId == null) {
        return Response(
          401,
          body: jsonEncode({'error': 'missing_security_headers'}),
        );
      }

      final ts = int.tryParse(tsStr) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Time Skew Check (±120s)
      if ((now - ts).abs() > 120000) {
        return Response(
          401,
          body: jsonEncode({'error': 'clock_skew_too_large'}),
        );
      }

      // 2. Nonce Replay Protection
      if (nonceStore.containsKey(nonce)) {
        return Response(401, body: jsonEncode({'error': 'nonce_reused'}));
      }
      nonceStore[nonce] = DateTime.now();

      // Cleanup nonces older than 5 mins
      nonceStore.removeWhere(
        (key, value) => DateTime.now().difference(value).inMinutes > 5,
      );

      // 3. Secret Lookup
      final secret = await getSecret(gardenerId, seedlingId);
      if (secret == null) {
        return Response(
          401,
          body: jsonEncode({'error': 'unauthorized_device'}),
        );
      }

      // 4. Canonical String & Signature Verification
      final body = await request.readAsString();
      final bodyHash = sha256.convert(utf8.encode(body)).toString();

      final canonical = [
        tsStr,
        nonce,
        request.method.toUpperCase(),
        request.url.path,
        request.url.query,
        bodyHash,
      ].join('\n');

      final hmac = Hmac(sha256, utf8.encode(secret));
      final computedSig = hmac.convert(utf8.encode(canonical)).toString();

      // Convert to base64url format as used in legacy
      final computedSigB64 = base64Url
          .encode(utf8.encode(computedSig))
          .replaceAll('=', '');

      // Note: Legacy used a slightly different b64 conversion, but the core is HMAC-SHA256.
      // We will normalize 2.0 to standard hex for clarity unless 1:1 wire parity is required.
      // Re-reading legacy: digest('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
      final rawMac = hmac.convert(utf8.encode(canonical)).bytes;
      final legacySig = base64Url.encode(rawMac).replaceAll('=', '');

      if (sig != legacySig) {
        return Response(401, body: jsonEncode({'error': 'invalid_signature'}));
      }

      // Re-read the request as the body stream was consumed
      final newRequest = request.change(body: body);
      return innerHandler(newRequest);
    };
  };
}
