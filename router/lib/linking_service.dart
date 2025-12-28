import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:router/db_service.dart';

class LinkingService {
  final DbService _db;
  final _uuid = const Uuid();

  LinkingService(this._db);

  /// Starts a linking process for a Gardener.
  Map<String, dynamic> startLinking(String gardenerId, {String? platform}) {
    final token = base64Url.encode(utf8.encode(_uuid.v4())).replaceAll('=', '');
    const ttlMs = 10 * 60 * 1000; // 10 minutes

    _db.upsertGardener(gardenerId, platform: platform);
    _db.createLinkToken(token, gardenerId, ttlMs);

    final expiresAt = DateTime.now().millisecondsSinceEpoch + ttlMs;

    return {
      'ok': true,
      'token': token,
      'gardener_id': gardenerId,
      'expires_at': expiresAt,
    };
  }

  /// Completes a linking process for a Seedling using a token.
  Map<String, dynamic>? completeLinking(String token, String seedlingId) {
    final tok = _db.getLinkToken(token);
    if (tok == null) return null;

    final gardenerId = tok['gardener_id'] as String;

    // 1:1 Parity: Binding caps (max 10)
    final gCount = _db.countBindingsForGardener(gardenerId);
    final sCount = _db.countBindingsForSeedling(seedlingId);
    if (gCount >= 10 || sCount >= 10) return null;

    // Generate a secure secret for HMAC communication
    final secret = base64Url
        .encode(utf8.encode(_uuid.v4()))
        .replaceAll('=', '');

    _db.upsertSeedling(seedlingId);
    _db.createBinding(gardenerId, seedlingId, secret);
    _db.deleteLinkToken(token);

    return {
      'ok': true,
      'gardener_id': gardenerId,
      'seedling_id': seedlingId,
      'secret': secret,
    };
  }
}
