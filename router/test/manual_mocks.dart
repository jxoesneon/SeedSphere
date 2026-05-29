import 'package:mockito/mockito.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/tracker_service.dart';
import 'package:seedsphere_core/seedsphere_core.dart' hide TrackerService;

class ManualMockDbService extends Mock implements DbService {}
class ManualMockEventService extends Mock implements EventService {}
class ManualMockTrackerService extends Mock implements TrackerService {
  @override
  Future<Map<String, dynamic>> optimize(List<String> trackers) async => {'added': <String>[]};
}
class ManualMockAppConfig extends Mock implements AppConfig {
  @override
  String get torznabUrl => '';
  @override
  Future<String?> getTorznabKey() async => null;
  @override
  bool get enableTorznab => false;
  @override
  String get trackerVariant => 'best';
  @override
  String get customTrackersUrl => '';
  @override
  bool get probeTrackers => false;
  @override
  bool get probeProviders => false;
  @override
  String get validationMode => 'basic';
  @override
  int get probeTimeoutMs => 5000;
  @override
  int get providerFetchTimeoutMs => 10000;
  @override
  int get maxResultsPerProvider => 20;
  @override
  bool get enableTrackerScraping => false;
}
