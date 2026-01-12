import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/providers/debrid_provider.dart';
import 'package:gardener/core/providers/premiumize_provider.dart';
import 'package:gardener/core/providers/all_debrid_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockDebridProvider extends Mock implements DebridProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockConfigManager mockConfig;
  late MockDebridProvider mockProvider;
  late StreamResolver resolver;

  setUp(() {
    mockConfig = MockConfigManager();
    mockProvider = MockDebridProvider();

    // Default config behavior
    when(() => mockConfig.debridService).thenReturn('real_debrid');
    when(
      () => mockConfig.getRealDebridToken(),
    ).thenAnswer((_) async => 'rd_token');
    when(() => mockConfig.backgroundDownload).thenReturn(false);
    when(
      () => mockConfig.getOrionApiKey(),
    ).thenAnswer((_) async => 'orion_token');
    when(
      () => mockConfig.getPremiumizeApiKey(),
    ).thenAnswer((_) async => 'prem_token');
    when(
      () => mockConfig.getAllDebridApiKey(),
    ).thenAnswer((_) async => 'ad_token');
    when(() => mockConfig.providerFailover).thenReturn(false);

    when(() => mockProvider.id).thenReturn('mock_provider');

    // Inject mockProvider into constructor for direct logic testing
    resolver = StreamResolver(config: mockConfig, provider: mockProvider);
  });

  group('StreamResolver Integration Tests', () {
    test('Should resolve stream using the injected provider', () async {
      // Stub the full resolution flow
      when(
        () => mockProvider.addMagnet(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => {'id': 'tor_id'});
      when(() => mockProvider.getTorrentInfo('tor_id')).thenAnswer(
        (_) async => {
          'status': 'downloaded',
          'links': ['http://ok.com/direct'],
        },
      );
      when(
        () => mockProvider.unrestrictLink('http://ok.com/direct'),
      ).thenAnswer(
        (_) async => {'download': 'http://ok.com/direct_stream.mkv'},
      );

      final result = await resolver.resolveStream('http://ok.com/file');

      expect(result, 'http://ok.com/direct_stream.mkv');
    });

    test(
      'Should handle Series Episode Selection logic (File Matching)',
      () async {
        when(
          () => mockProvider.addMagnet(any(), options: any(named: 'options')),
        ).thenAnswer((_) async => {'id': 'tor_id'});

        // Mock torrentinfo with multiple files
        final torrentInfo = {
          'status': 'downloaded',
          'files': [
            {'id': '1', 'path': 'Show.S01E01.mkv', 'link': 'link1'},
            {'id': '2', 'path': 'Show.S01E02.mkv', 'link': 'link2'},
          ],
          'links': ['link1', 'link2'],
          'selected_files': ['1', '2'], // Mock standard debrid format
        };

        when(
          () => mockProvider.getTorrentInfo('tor_id'),
        ).thenAnswer((_) async => torrentInfo);
        when(
          () => mockProvider.unrestrictLink('link2'),
        ).thenAnswer((_) async => {'download': 'http://ok.com/s01e02.mkv'});

        // Resolve for S01E02
        final result = await resolver.resolveStream(
          'infohash',
          episodeMatcher: RegExp(r'S01E02', caseSensitive: false),
        );

        expect(result, 'http://ok.com/s01e02.mkv');
      },
    );

    test('Should fail gracefully if provider returns error status', () async {
      when(
        () => mockProvider.addMagnet(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => {'id': 'tor_id'});
      when(
        () => mockProvider.getTorrentInfo('tor_id'),
      ).thenAnswer((_) async => {'status': 'error'});

      final result = await resolver.resolveStream('some_link');

      expect(result, isNull);
    });
  });

  group('Provider Factory Logic (Mocking Config Only)', () {
    test('Should instantiate PremiumizeProvider when selected', () async {
      final factoryResolver = StreamResolver(
        config: mockConfig,
      ); // No testProvider
      when(() => mockConfig.debridService).thenReturn('premiumize');
      when(() => mockConfig.getRealDebridToken()).thenAnswer((_) async => null);
      when(() => mockConfig.getOrionApiKey()).thenAnswer((_) async => null);
      when(
        () => mockConfig.getPremiumizeApiKey(),
      ).thenAnswer((_) async => 'key');
      when(() => mockConfig.getAllDebridApiKey()).thenAnswer((_) async => null);

      final provider = await factoryResolver.getProvider();
      expect(provider, isA<PremiumizeProvider>());
    });

    test('Should instantiate AllDebridProvider when selected', () async {
      final factoryResolver = StreamResolver(
        config: mockConfig,
      ); // No testProvider
      when(() => mockConfig.debridService).thenReturn('all_debrid');
      when(() => mockConfig.getRealDebridToken()).thenAnswer((_) async => null);
      when(() => mockConfig.getOrionApiKey()).thenAnswer((_) async => null);
      when(
        () => mockConfig.getPremiumizeApiKey(),
      ).thenAnswer((_) async => null);
      when(
        () => mockConfig.getAllDebridApiKey(),
      ).thenAnswer((_) async => 'key');

      final provider = await factoryResolver.getProvider();
      expect(provider, isA<AllDebridProvider>());
    });
  });
}
