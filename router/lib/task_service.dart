import 'dart:math';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Manages distributed tasks (offloading work to Gardeners).
class TaskService {
  final String _secret;

  /// Creates a TaskService with the given JWT [_secret].
  TaskService(this._secret);

  /// Creates a signed task token for a Gardener to execute.
  ///
  /// Returns the JWT string.
  String requestTask(String type, Map<String, dynamic> payload) {
    if (_secret.isEmpty) throw Exception('TaskService secret not configured');

    final taskId =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    final jwt = JWT({
      'typ': 'task',
      'task_id': taskId,
      'task_type': type,
      'payload': payload,
    });

    // Sign with 5 min expiry
    final token = jwt.sign(
      SecretKey(_secret),
      expiresIn: const Duration(minutes: 5),
    );

    // Store completer to handle result (optional, if we want request-response flow)
    // For now, fire-and-forget or async result collection.
    // Legacy system: Gardener requests task, Server issues one.
    // My architecture: Server *pushes* or Gardener *requests*?
    // Legacy: `POST /api/tasks/request` -> Server returns task?
    // Or `POST /api/tasks/dispatch` -> Server returns token.

    // Let's implement Dispatch pattern:
    // 1. Server generates token.
    // 2. Returns to caller (Gardener).
    // 3. Gardener processes.
    // 4. Gardener POST /result with token + result.

    // Actually, usually Server has a queue. Gardener polls.
    // But simplistic approach: generic signing oracle.
    // Caller asks "I want to do X", Server signs "Do X", Gardener verifies signature?
    // No, usually Server wants work done.

    // Let's match legacy: `POST /api/tasks/request` (Gardener asks for work)
    // Server checks queue.
    // If work, returns `{ token: JWT(task) }`.
    // Gardener does it.
    // `POST /api/tasks/result` `{ token: ..., result: ... }`.

    // Given we don't have a real job queue yet (except maybe verify trackers?),
    // I'll implement the Mechanism (Signing/Verifying) so it's ready.
    // And a simple Echo task for testing.

    return token;
  }

  /// Verifies a task result.
  Map<String, dynamic>? verifyResult(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      // Check if task was actually issued by us and not expired
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
