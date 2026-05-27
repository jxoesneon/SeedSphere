import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:router/db_service.dart';

/// Controller for processing and logging incoming telemetry data.
class TelemetryController {
  /// The database service used to write audit logs.
  final DbService db;

  /// Creates a new instance of [TelemetryController].
  TelemetryController(this.db);

  /// Handles incoming telemetry requests and verifies security keys.
  Future<Response> handle(Request req) async {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);

    // Fail-closed telemetry: Require authentication if key is configured.
    final sharedKey = Platform.environment['TELEMETRY_KEY'];
    if (sharedKey == null || sharedKey.isEmpty) {
      return Response(
        403,
        body: jsonEncode({'ok': false, 'error': 'telemetry_disabled'}),
      );
    }

    final provided =
        req.headers['x-telemetry-key'] ?? req.url.queryParameters['key'] ?? '';

    if (provided != sharedKey) {
      return Response(
        401,
        body: jsonEncode({'ok': false, 'error': 'unauthorized'}),
      );
    }

    db.writeAudit('telemetry', {'ua': req.headers['user-agent'], 'body': data});

    return Response.ok(
      jsonEncode({'ok': true}),
      headers: {
        'content-type': 'application/json',
        'Cache-Control': 'no-store',
      },
    );
  }
}
