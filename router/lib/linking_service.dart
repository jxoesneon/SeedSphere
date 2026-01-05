import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:router/db_service.dart';

/// Service managing the 1:1 linking process between Gardeners and Seedlings/Users.
///
/// Uses HMAC primitives and temporary tokens to establish secure bindings.
class LinkingService {
  final DbService _db;
  final _uuid = const Uuid();

  /// Creates a new LinkingService.
  LinkingService(this._db);

  /// Starts a linking process for a Gardener.
  ///
  /// Generates a unique, time-limited token that a Seedling can use to complete the linking.
  /// Optionally records the platform from which the linking was initiated.
  ///
  /// Returns a map containing the token, gardener ID, and its expiration time.
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
  ///
  /// Verifies the provided token, checks binding limits, and if valid,
  /// establishes a secure binding between the Gardener and Seedling.
  /// A unique secret is generated for HMAC communication between the bound entities.
  ///
  /// Returns a map with binding details (gardener ID, seedling ID, secret) on success,
  /// or `null` if the token is invalid or binding limits are exceeded.
  Map<String, dynamic>? completeLinking(String token, String seedlingId) {
    return _db.transaction(() {
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
    });
  }

  /// Directly binds a Gardener to a Seedling without a token exchange.
  ///
  /// Used for implicit linking during authenticated sessions (e.g. Google Login).
  ///
  /// Returns the shared secret.
  String? bindDirectly(String gardenerId, String seedlingId) {
    // Check for existing binding first to preserve secret if already linked
    final secretOverride = _db.getBindingSecret(gardenerId, seedlingId);
    if (secretOverride != null) {
      return secretOverride;
    }

    // Check limits
    final gCount = _db.countBindingsForGardener(gardenerId);
    final sCount = _db.countBindingsForSeedling(seedlingId);
    if (gCount >= 10 || sCount >= 10) return null;

    final secret = base64Url
        .encode(utf8.encode(_uuid.v4()))
        .replaceAll('=', '');

    _db.upsertSeedling(seedlingId);
    _db.createBinding(gardenerId, seedlingId, secret);
    return secret;
  }
}
