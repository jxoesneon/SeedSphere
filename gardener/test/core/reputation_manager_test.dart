import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/core/reputation_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';

class MockP2PManager extends Mock implements P2PManager {}

// Helper to match P2PCommand
class P2PCommandFake extends Fake implements P2PCommand {}

void main() {
  late MockP2PManager mockP2P;
  late ReputationManager manager;

  setUp(() {
    mockP2P = MockP2PManager();
    manager = ReputationManager(mockP2P);
    registerFallbackValue(P2PCommandFake());
  });

  group('ReputationManager', () {
    test('Starts at 0', () {
      expect(manager.getScore('peer1'), 0);
    });

    test('Increments score on positive delta', () {
      manager.adjustScore('peer1', 10);
      expect(manager.getScore('peer1'), 10);
    });

    test('Decrements score on negative delta', () {
      manager.adjustScore('peer1', -10);
      expect(manager.getScore('peer1'), -10);
    });

    test('Blacklists peer when threshold reached', () {
      // Threshold is -50
      manager.adjustScore('peerBad', -40);
      expect(manager.isBlacklisted('peerBad'), isFalse);

      manager.adjustScore('peerBad', -11); // Total -51
      expect(manager.getScore('peerBad'), -51);
      expect(manager.isBlacklisted('peerBad'), isTrue);

      // Verify blacklist command sent
      final captured = verify(() => mockP2P.sendCommand(captureAny())).captured;
      final command = captured.last as P2PCommand;

      expect(command.type, P2PCommandType.blacklist);
      expect(command.data?['peerId'], 'peerBad');
    });
  });
}
