import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_async/fake_async.dart';
import 'package:router/prefetch_service.dart';
import 'package:router/scraper_service.dart';

@GenerateNiceMocks([MockSpec<ScraperService>()])
import 'prefetch_service_test.mocks.dart';

void main() {
  group('PrefetchService', () {
    late PrefetchService prefetch;
    late MockScraperService mockScraper;

    setUp(() {
      mockScraper = MockScraperService();
      prefetch = PrefetchService(mockScraper);
      when(mockScraper.getStreams(any, any, any)).thenAnswer((_) async => []);
    });

    test('start warms cache immediately', () {
      fakeAsync((async) {
        when(mockScraper.getStreams(any, any, any)).thenAnswer((_) async => []);

        prefetch.start();
        async.flushMicrotasks();

        verify(mockScraper.getStreams(any, any, any)).called(greaterThan(0));
      });
    });

    test('start schedules periodic updates', () {
      fakeAsync((async) {
        prefetch.start();

        // Initial warm
        async.flushMicrotasks();
        verify(mockScraper.getStreams(any, any, any)).called(greaterThan(0));
        clearInteractions(mockScraper);

        // Advance 6 hours
        async.elapse(const Duration(hours: 6));

        verify(mockScraper.getStreams(any, any, any)).called(greaterThan(0));

        prefetch.stop();
      });
    });

    test('stop cancels timer', () {
      fakeAsync((async) {
        prefetch.start();
        async.flushMicrotasks(); // Allow initial warm to complete
        prefetch.stop();

        clearInteractions(mockScraper);

        async.elapse(const Duration(hours: 12));

        verifyNever(mockScraper.getStreams(any, any, any));
      });
    });
  });
}
