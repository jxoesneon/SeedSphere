import 'package:test/test.dart';
import 'package:router/pairing_service.dart';

void main() {
  group('PairingService', () {
    late PairingService pairingService;

    setUp(() {
      pairingService = PairingService();
    });

    test('Full Pairing Flow', () async {
      final pin = await pairingService.createSession('seed1');
      expect(pin, hasLength(6));

      var session = pairingService.getSession(pin);
      expect(session, isNotNull);
      expect(session!.seedlingId, 'seed1');
      expect(session.isComplete, isFalse);

      final result = await pairingService.completePairing(pin, 'gard1');
      expect(result, isNotNull);
      expect(result!.gardenerId, 'gard1');
      expect(result.seedlingId, 'seed1');

      session = pairingService.getSession(pin);
      expect(session!.isComplete, isTrue);
    });

    test('Invalid PIN', () async {
      final result = await pairingService.completePairing('000000', 'gard1');
      expect(result, isNull);
    });
  });
}
