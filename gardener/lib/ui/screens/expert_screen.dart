import 'dart:async';
import 'dart:math';
import 'dart:ui'; // For lerpDouble
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/activity_chart.dart';
import 'package:gardener/ui/widgets/live_log.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/widgets/scraper_spectrum.dart';
import 'package:gardener/ui/widgets/density_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpertScreen extends ConsumerStatefulWidget {
  const ExpertScreen({super.key});

  @override
  ConsumerState<ExpertScreen> createState() => _ExpertScreenState();
}

class _ExpertScreenState extends ConsumerState<ExpertScreen>
    with SingleTickerProviderStateMixin {
  // Data buffers
  final List<double> _heartbeatActivity = List.filled(150, 0.0, growable: true);
  final List<double> _taskActivity = List.filled(150, 0.0, growable: true);
  final List<double> _peerHistory = List.filled(
    60,
    0.0,
    growable: true,
  ); // 60s history
  final List<String> _logs = [];

  // Scraper State Map
  final Map<String, ScraperState> _scraperStates = {};

  final Random _rng = Random();

  // Noise smoothing
  double _noiseTarget = 0.0;
  double _currentNoise = 0.0;

  // EKG Pulse Queues
  final List<double> _heartbeatQueue = [];
  final List<double> _taskQueue = [];

  // Ticker for VSync-locked updates
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Duration _accumulator = Duration.zero;
  final Duration _timeStep = const Duration(microseconds: 16666);

  Timer? _slowPollTimer;
  StreamSubscription? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToP2P();

    // Create VSync ticker
    _ticker = createTicker(_onTick)..start();

    // Slow Poll Timer (1s) for Peer Density and idle cleanup
    _slowPollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final count = ref.read(p2pManagerProvider).peerCount.value;
      setState(() {
        // Add subtle jitter to the peer count density chart: +/- 0.5
        final jitter = (_rng.nextDouble() * 1.0) - 0.5;
        _peerHistory.add(count.toDouble() + jitter);
        if (_peerHistory.length > 60) _peerHistory.removeAt(0);

        // Decay Scraper Status back to Idle if old
        final now = DateTime.now();
        for (var key in _scraperStates.keys) {
          final state = _scraperStates[key]!;
          if (state.status != ScraperStatus.idle &&
              now.difference(state.lastUpdated).inSeconds > 10) {
            // Reset to idle after 10s of inactivity
            _scraperStates[key] = state.copyWith(status: ScraperStatus.idle);
          }
        }
      });
    });

    _initScrapers();
  }

  void _initScrapers() {
    // Pre-populate with known major scrapers
    final defaults = [
      'Torrentio',
      'YTS',
      'Eztv',
      '1337x',
      'TPB',
      'Galaxy',
      'Torlock',
      'MagnetDL',
      'Anidex',
      'Tosho',
      'Zooqle',
      'Rutor',
      'Torznab',
    ];
    for (var name in defaults) {
      _scraperStates[name] = ScraperState(name: name);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _accumulator += dt;

    bool didUpdate = false;

    while (_accumulator >= _timeStep) {
      _accumulator -= _timeStep;
      _simulationStep();
      didUpdate = true;
    }

    if (didUpdate) {
      setState(() {});
    }
  }

  void _simulationStep() {
    // Heartbeat Chart Update
    if (_heartbeatQueue.isNotEmpty) {
      _shiftAndAdd(_heartbeatActivity, _heartbeatQueue.removeAt(0));
    } else {
      _shiftAndAdd(_heartbeatActivity, 0.0);
    }

    // Task Chart Update
    if (_taskQueue.isNotEmpty) {
      _shiftAndAdd(_taskActivity, _taskQueue.removeAt(0));
    } else {
      // Artificial "Live Wire" noise with smoothing
      if (_rng.nextDouble() < 0.05) {
        // Reduced jitter: Target +/- 2.5 (was +/- 5.0)
        _noiseTarget = (_rng.nextDouble() * 5.0) - 2.5;
      }
      _currentNoise = lerpDouble(_currentNoise, _noiseTarget, 0.1) ?? 0.0;
      _shiftAndAdd(_taskActivity, _currentNoise);
    }
  }

  void _subscribeToP2P() {
    final manager = ref.read(p2pManagerProvider);
    _sseSubscription = manager.eventStream.listen((event) {
      if (mounted) {
        _processEvent(event);
      }
    });
  }

  void _processEvent(Map<String, dynamic> event) {
    // 1. Accumulate Heartbeats
    if (event.containsKey('t')) {
      _queuePulse(_heartbeatQueue);
    }

    // 2. Accumulate Tasks
    if (event.containsKey('type') && event['type'] == 'task') {
      _queuePulse(_taskQueue);
      _addLog('[TASK] ${event['type']} received');
    }

    // 3. General Logs
    if (event['type'] == 'log') {
      _addLog(event['message'] ?? event.toString());
    }

    // 4. Scraper Events
    if (event['type'] == 'scraper_event') {
      _addLog('[SCRAPER] ${event['scraper']} - ${event['event']}');

      final name = event['scraper'] as String;
      final type = event['event'] as String;

      ScraperStatus status = ScraperStatus.idle;
      int yieldCount = _scraperStates[name]?.yieldCount ?? 0;

      if (type == 'start') status = ScraperStatus.searching;
      if (type == 'done') {
        status = ScraperStatus.done;
        yieldCount = event['count'] ?? 0;
      }
      if (type == 'error') status = ScraperStatus.error;

      // Update state
      if (_scraperStates.containsKey(name) || type == 'start') {
        _scraperStates[name] = ScraperState(
          name: name,
          status: status,
          yieldCount: yieldCount,
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  // Simulates a P-QRS-T complex
  void _queuePulse(List<double> queue) {
    queue.addAll([5.0, 8.0, 10.0, 8.0, 5.0, 0.0, 0.0]); // P-wave
    queue.addAll([-5.0, -10.0, -5.0]); // Q-wave
    queue.addAll([20.0, 60.0, 100.0, 60.0, 20.0]); // R-wave
    queue.addAll([-10.0, -20.0, -10.0, 0.0]); // S-wave
    queue.addAll([0.0, 0.0, 0.0]); // ST segment
    queue.addAll([5.0, 10.0, 15.0, 10.0, 5.0, 0.0]); // T-wave
  }

  void _shiftAndAdd(List<double> list, double value) {
    list.removeAt(0);
    list.add(value);
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(
        '[${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)}] $msg',
      );
      if (_logs.length > 100) _logs.removeAt(0);
    });
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _slowPollTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(p2pManagerProvider);
    final metadata = manager.diagnosticMetadata;

    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text(
          'Swarm Intelligence',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Diagnostic Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AethericTheme.aetherBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'STATUS',
                    metadata['status'] ?? 'Unknown',
                    Colors.greenAccent,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'PEER ID',
                    metadata['peerId'] ?? 'Unknown',
                    Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'LISTENING',
                    metadata['addresses'] ?? 'None',
                    Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'GARDENER ID',
                    manager.gardenerId ?? 'Unlinked',
                    const Color(0xFFFF00FF),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Charts
            ActivityChart(
              dataPoints: List.from(_heartbeatActivity),
              title: 'SWARM HEARTBEAT',
              color: AethericTheme.aetherBlue,
            ),

            const SizedBox(height: 16),

            ActivityChart(
              dataPoints: List.from(_taskActivity),
              title: 'TASK VELOCITY',
              color: const Color(0xFFFF00FF), // Magenta for tasks
            ),
            const SizedBox(height: 16),

            // Neural Resonance
            ScraperSpectrum(scrapers: _scraperStates.values.toList()),

            const SizedBox(height: 16),

            // Swarm Density
            DensityChart(peerHistory: _peerHistory, title: 'SWARM DENSITY'),

            const SizedBox(height: 24),

            // Live Log
            SizedBox(height: 300, child: LiveLog(logs: _logs)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.firaCode(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.firaCode(color: valueColor, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
