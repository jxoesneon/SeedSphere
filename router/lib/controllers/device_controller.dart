import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:router/core/server_context.dart';
import 'package:router/db_service.dart';

/// Controller for managing device-specific states and link statuses.
class DeviceController {
  /// The database service used to query device/owner data.
  final DbService db;

  /// Creates a new instance of [DeviceController].
  DeviceController(this.db);

  /// Retrieves the link status and swarm neighbors for a specific device.
  Future<Response> status(Request req, String id) async {
    final ownerId = db.getOwnerForDevice(id);
    final isLinked = ownerId != null;

    var neighbors = 0;
    var ownerDisplay = 'None';

    if (isLinked) {
      final bindings = db.getBindings(ownerId);
      neighbors = bindings.length - 1;

      final owner = db.getUser(ownerId);
      if (owner != null) {
        final email = owner['email'] as String?;
        if (email != null) {
          final parts = email.split('@');
          ownerDisplay = '${parts[0].substring(0, 1)}***@${parts[1]}';
        } else {
          ownerDisplay = 'User: ${ownerId.substring(0, 8)}...';
        }
      }
    }

    return Response.ok(
      jsonEncode({
        'ok': true,
        'id': id,
        'linked': isLinked,
        'owner': ownerDisplay,
        'neighbors': neighbors,
      }),
      headers: {
        'content-type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  /// Unlinks a device from its owner, requiring JWT authentication and verification.
  Future<Response> unlink(
    Request req,
    String id,
    ServerContext services,
  ) async {
    final authHeader = req.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({'ok': false, 'error': 'unauthorized'}),
      );
    }

    final token = authHeader.substring(7);
    final claims = services.auth.verifyJwt(token);
    if (claims == null) {
      return Response(
        401,
        body: jsonEncode({'ok': false, 'error': 'invalid_token'}),
      );
    }

    final ownerId = db.getOwnerForDevice(id);
    final tokenUserId = claims['sub'] as String?;

    if (ownerId == null || tokenUserId == null || ownerId != tokenUserId) {
      return Response(
        403,
        body: jsonEncode({'ok': false, 'error': 'forbidden'}),
      );
    }

    db.unlinkDevice(id);
    db.writeAudit('device_unlink', {'device_id': id, 'owner_id': ownerId});

    return Response.ok(jsonEncode({'ok': true}));
  }
}
