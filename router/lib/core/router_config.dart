import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:router/db_service.dart';

/// Implementation of AppConfig for the Router project.
class RouterConfig implements AppConfig {
  final DbService _db;

  RouterConfig(this._db);

  @override
  String get torznabUrl => ''; // Global router doesn't use individual torznab

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
