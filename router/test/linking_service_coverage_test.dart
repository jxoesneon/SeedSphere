import 'package:test/test.dart';
import 'package:router/linking_service.dart';
import 'package:router/db_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<DbService>()])
import 'linking_service_coverage_test.mocks.dart';

void main() {
  group('LinkingService Full Coverage', () {
    late LinkingService linkingService;
    late MockDbService mockDb;

    setUp(() {
      mockDb = MockDbService();
      linkingService = LinkingService(mockDb);
    });

    test('startLinking creates token', () {
      final res = linkingService.startLinking('g1', platform: 'ios');
      expect(res['token'], isNotNull);
      verify(mockDb.createLinkToken(any, 'g1', any)).called(1);
    });

    test('completeLinking verifies and binds', () async {
      when(mockDb.getLinkToken('t1')).thenReturn({'gardener_id': 'g1'});
      when(mockDb.countBindingsForGardener('g1')).thenReturn(0);
      when(mockDb.countBindingsForSeedling('s1')).thenReturn(0);
      when(mockDb.transaction(any)).thenAnswer((inv) {
        final callback = inv.positionalArguments[0] as Function();
        return callback();
      });
      
      final res = linkingService.completeLinking('t1', 's1');
      expect(res?['ok'], isTrue);
      verify(mockDb.deleteLinkToken('t1')).called(1);
      verify(mockDb.createBinding('g1', 's1', any)).called(1);
    });

    test('bindDirectly generates secret', () {
      when(mockDb.getBindingSecret('g1', 's1')).thenReturn(null);
      when(mockDb.countBindingsForGardener('g1')).thenReturn(0);
      when(mockDb.countBindingsForSeedling('s1')).thenReturn(0);

      final secret = linkingService.bindDirectly('g1', 's1');
      expect(secret, isNotEmpty);
      verify(mockDb.createBinding('g1', 's1', any)).called(1);
    });
  });
}
