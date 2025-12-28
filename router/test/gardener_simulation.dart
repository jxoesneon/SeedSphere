import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simulations of Gardener-side Distributed Verification
///
/// 1. Syncs tracker list.
/// 2. "Verifies" them (mock).
/// 3. Submits votes.
/// 4. Checks if "Best" list is updated.
void main() async {
  print('--- Distributed Verification Simulation ---');
  final router = 'http://localhost:8080';

  // 1. Sync
  print('1. Syncing tracker list...');
  // Force ingestion if empty logic isn't explicit, but ingestion runs on startup.
  await Future.delayed(Duration(seconds: 2));

  final syncRes = await http.get(Uri.parse('$router/api/trackers/sync'));
  print('Sync Status: ${syncRes.statusCode}');

  if (syncRes.statusCode == 200) {
    final data = jsonDecode(syncRes.body);
    final trackers = (data['trackers'] as List).cast<String>();
    print('Received ${trackers.length} trackers to verify.');

    if (trackers.isNotEmpty) {
      // 2. Simulate Voting
      // Pick top 5 and vote UP with low latency
      final votes = trackers
          .take(5)
          .map(
            (t) => {
              'url': t,
              'up': true,
              'latency': 25, // super fast
            },
          )
          .toList();

      print('2. Submitting ${votes.length} votes...');
      final voteRes = await http.post(
        Uri.parse('$router/api/trackers/vote'),
        body: jsonEncode({'votes': votes}),
      );
      print('Vote Status: ${voteRes.statusCode}');

      // 3. Check Best
      print('3. Checking "Best" list...');
      final bestRes = await http.get(Uri.parse('$router/api/trackers/best'));
      final bestData = jsonDecode(bestRes.body);
      final bestList = (bestData['trackers'] as List).cast<String>();

      print('Best List Count: ${bestList.length}');
      if (bestList.isNotEmpty) {
        print('Top Best: ${bestList.first}');
        // Verify our voted ones are in there (latency sorting might put them top if they started at 0 score)
        if (bestList.contains(trackers.first)) {
          print('✅ Success: Voted tracker promoted to Best list.');
        } else {
          print(
            '⚠️ Voted tracker not found in best list (maybe score threshold not met yet?)',
          );
        }
      } else {
        print('⚠️ No trackers in Best list yet (Scores start at 0)');
      }
    } else {
      print('⚠️ Sync list empty. Ingestion might still be running.');
    }
  }

  print('--- Simulation Complete ---');
}
