import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/providers/debrid_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([ConfigManager, DebridProvider])
import 'stream_resolver_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Should return placeholder link when backgroundDownload is enabled',
    () async {
      final mockConfig = MockConfigManager();
      final mockProvider = MockDebridProvider();

      when(mockConfig.debridService).thenReturn('real_debrid');
      when(mockConfig.backgroundDownload).thenReturn(true);
      when(
        mockProvider.addMagnet(any, options: anyNamed('options')),
      ).thenAnswer((_) async => {'id': 'bg_magnet_123'});
      when(mockProvider.id).thenReturn('bg_provider');

      final resolver = StreamResolver(
        config: mockConfig,
        provider: mockProvider,
      );
      final result = await resolver.resolveStream('magnet:?xt=urn:btih:bg123');

      expect(
        result,
        contains('seedsphere://background-download-started?id=bg_magnet_123'),
      );
    },
  );

  test(
    'Should proceed with full resolution when backgroundDownload is disabled',
    () async {
      final mockConfig = MockConfigManager();
      final mockProvider = MockDebridProvider();

      when(mockConfig.debridService).thenReturn('real_debrid');
      when(mockConfig.backgroundDownload).thenReturn(false);
      when(
        mockProvider.addMagnet(any, options: anyNamed('options')),
      ).thenAnswer((_) async => {'id': 'normal_magnet'});
      when(mockProvider.getTorrentInfo('normal_magnet')).thenAnswer(
        (_) async => {
          'status': 'downloaded',
          'links': ['https://rd.link'],
        },
      );
      when(
        mockProvider.unrestrictLink(any),
      ).thenAnswer((_) async => {'download': 'https://stream.direct'});
      when(mockProvider.id).thenReturn('normal_provider');

      final resolver = StreamResolver(
        config: mockConfig,
        provider: mockProvider,
      );
      final result = await resolver.resolveStream('normal_magnet');

      expect(result, 'https://stream.direct');
    },
  );

  test('Should handle checkAvailability calls', () async {
    final mockConfig = MockConfigManager();
    final mockProvider = MockDebridProvider();

    when(
      mockProvider.checkAvailability(any),
    ).thenAnswer((_) async => {'hash': true});

    final resolver = StreamResolver(config: mockConfig, provider: mockProvider);
    final res = await resolver.checkAvailability(['hash']);

    expect(res['hash'], true);
  });
}
