import 'package:router/auth_service.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/health_service.dart';
import 'package:router/linking_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/pairing_service.dart';
import 'package:router/p2p_node.dart';
import 'package:router/prefetch_service.dart';
import 'package:router/swarm_service.dart';
import 'package:router/task_service.dart';
import 'package:router/tracker_service.dart';
import 'package:router/boost_service.dart';
import 'package:router/addon_service.dart';
import 'package:router/services/distributed_scraper_service.dart';
import 'package:router/services/status_service.dart';

/// Container for all server-side services.
///
/// Enables dependency injection by passing this context
/// to route handlers instead of relying on global singletons.
class ServerContext {
  /// Database service for persistence.
  final DbService db;

  /// Service for PIN-based device pairing.
  final PairingService pairing;

  /// P2P networking node.
  final P2PNode p2p;

  /// Event broadcasting service (SSE).
  final EventService events;

  /// HMAC-based device linking service.
  final LinkingService linking;

  /// Connectivity health check service.
  final HealthService health;

  /// P2P swarm management service.
  final SwarmService swarm;

  /// Email notification service.
  final MailerService mailer;

  /// Bittorrent tracker management service.
  final TrackerService tracker;

  /// External metadata scraper service.
  final DistributedScraperService scraper;

  /// Stremio Addon manifest service.
  final AddonService addon;

  /// Authentication and JWT service.
  final AuthService auth;

  /// Stream boost and quality service.
  final BoostService boost;

  /// Background content prefetching service.
  final PrefetchService prefetch;

  /// Background task execution service.
  final TaskService task;

  /// Active status and heartbeat service.
  final StatusService status;

  /// Creates a new [ServerContext] with the given service instances.
  ServerContext({
    required this.db,
    required this.pairing,
    required this.p2p,
    required this.events,
    required this.linking,
    required this.health,
    required this.swarm,
    required this.mailer,
    required this.tracker,
    required this.scraper,
    required this.addon,
    required this.auth,
    required this.boost,
    required this.prefetch,
    required this.task,
    required this.status,
  });
}
