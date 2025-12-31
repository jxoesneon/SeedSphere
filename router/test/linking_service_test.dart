import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/linking_service.dart';
import 'package:router/db_service.dart';

@GenerateNiceMocks([MockSpec<DbService>()])
import 'linking_service_test.mocks.dart';

void main() {
  group('LinkingService', () {
    late LinkingService linkingService;
    late MockDbService mockDb;

    setUp(() {
      mockDb = MockDbService();
      linkingService = LinkingService(mockDb);
    });

    group('startLinking', () {
      test('generates valid token and calls db', () {
        final result = linkingService.startLinking(
          'gardener-123',
          platform: 'android',
        );

        expect(result['ok'], isTrue);
        expect(result['token'], isNotEmpty);
        expect(result['gardener_id'], equals('gardener-123'));
        expect(result['expires_at'], isA<int>());

        verify(
          mockDb.upsertGardener('gardener-123', platform: 'android'),
        ).called(1);
        verify(mockDb.createLinkToken(any, 'gardener-123', any)).called(1);
      });
    });

    group('completeLinking', () {
      test('returns null if token not found', () {
        when(
          mockDb.transaction(any),
        ).thenAnswer((inv) => inv.positionalArguments[0]());
        when(mockDb.getLinkToken('invalid-token')).thenReturn(null);

        final result = linkingService.completeLinking(
          'invalid-token',
          'seedling-123',
        );

        expect(result, isNull);
      });

      test('returns null if gardener limit reached', () {
        when(
          mockDb.transaction(any),
        ).thenAnswer((inv) => inv.positionalArguments[0]());
        when(
          mockDb.getLinkToken('valid-token'),
        ).thenReturn({'gardener_id': 'gardener-123'});
        when(mockDb.countBindingsForGardener('gardener-123')).thenReturn(10);

        final result = linkingService.completeLinking(
          'valid-token',
          'seedling-123',
        );

        expect(result, isNull);
      });

      test('returns null if seedling limit reached', () {
        when(
          mockDb.transaction(any),
        ).thenAnswer((inv) => inv.positionalArguments[0]());
        when(
          mockDb.getLinkToken('valid-token'),
        ).thenReturn({'gardener_id': 'gardener-123'});
        when(mockDb.countBindingsForGardener('gardener-123')).thenReturn(0);
        when(mockDb.countBindingsForSeedling('seedling-123')).thenReturn(10);

        final result = linkingService.completeLinking(
          'valid-token',
          'seedling-123',
        );

        expect(result, isNull);
      });

      test('completes linking successfully', () {
        when(
          mockDb.transaction(any),
        ).thenAnswer((inv) => inv.positionalArguments[0]());
        when(
          mockDb.getLinkToken('valid-token'),
        ).thenReturn({'gardener_id': 'gardener-123'});
        when(mockDb.countBindingsForGardener('gardener-123')).thenReturn(0);
        when(mockDb.countBindingsForSeedling('seedling-123')).thenReturn(0);

        final result = linkingService.completeLinking(
          'valid-token',
          'seedling-123',
        );

        expect(result, isNotNull);
        expect(result!['ok'], isTrue);
        expect(result['gardener_id'], equals('gardener-123'));
        expect(result['seedling_id'], equals('seedling-123'));
        expect(result['secret'], isNotEmpty);

        verify(mockDb.upsertSeedling('seedling-123')).called(1);
        verify(
          mockDb.createBinding('gardener-123', 'seedling-123', any),
        ).called(1);
        verify(mockDb.deleteLinkToken('valid-token')).called(1);
      });
    });
  });
}
