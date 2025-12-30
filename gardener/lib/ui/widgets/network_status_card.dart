import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Network connectivity status for the swarm uplink.
enum NetworkStatus {
  /// Optimal connectivity with good peer count
  optimal,

  /// Limited connectivity or degraded performance
  degraded,

  /// No network connection
  offline,

  /// Checking connection status
  checking,
}

/// A status card displaying real-time network health for P2P connectivity.
///
/// Features:
/// - Connection state indicator (Optimal/Degraded/Offline)
/// - Animated peer count
/// - Real-time metrics (latency, region)
/// - Quick action buttons (Optimize, Details)
/// - Status-driven CTAs based on network health
///
/// Following 2025 UX principles:
/// - Status-first design
/// - Real-time feedback
/// - Contextual actions
class NetworkStatusCard extends StatefulWidget {
  /// Current network status
  final NetworkStatus status;

  /// Number of connected peers
  final int peerCount;

  /// Network latency in milliseconds
  final int? latencyMs;

  /// Geographic region of connection
  final String? region;

  /// Callback for optimize action
  final VoidCallback? onOptimize;

  /// Callback for details action
  final VoidCallback? onShowDetails;

  const NetworkStatusCard({
    super.key,
    required this.status,
    required this.peerCount,
    this.latencyMs,
    this.region,
    this.onOptimize,
    this.onShowDetails,
  });

  @override
  State<NetworkStatusCard> createState() => _NetworkStatusCardState();
}

class _NetworkStatusCardState extends State<NetworkStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _displayedPeerCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _displayedPeerCount = widget.peerCount;
  }

  @override
  void didUpdateWidget(NetworkStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerCount != widget.peerCount) {
      _animatePeerCount(oldWidget.peerCount, widget.peerCount);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _animatePeerCount(int from, int to) {
    final duration = const Duration(milliseconds: 500);
    final steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;
    final diff = to - from;

    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: stepDuration * i), () {
        if (mounted) {
          setState(() {
            _displayedPeerCount = from + ((diff * i) ~/ steps);
          });
        }
      });
    }
  }

  Color get _statusColor {
    switch (widget.status) {
      case NetworkStatus.optimal:
        return const Color(0xFF10B981); // Green
      case NetworkStatus.degraded:
        return const Color(0xFFF59E0B); // Amber
      case NetworkStatus.offline:
        return const Color(0xFFEF4444); // Red
      case NetworkStatus.checking:
        return Colors.white38;
    }
  }

  IconData get _statusIcon {
    switch (widget.status) {
      case NetworkStatus.optimal:
        return Icons.check_circle_rounded;
      case NetworkStatus.degraded:
        return Icons.warning_rounded;
      case NetworkStatus.offline:
        return Icons.cloud_off_rounded;
      case NetworkStatus.checking:
        return Icons.sync_rounded;
    }
  }

  String get _statusText {
    switch (widget.status) {
      case NetworkStatus.optimal:
        return 'Connected';
      case NetworkStatus.degraded:
        return 'Limited Connectivity';
      case NetworkStatus.offline:
        return 'Offline';
      case NetworkStatus.checking:
        return 'Checking...';
    }
  }

  String get _statusDescription {
    switch (widget.status) {
      case NetworkStatus.optimal:
        return '$_displayedPeerCount peers connected';
      case NetworkStatus.degraded:
        return 'Only $_displayedPeerCount peers available';
      case NetworkStatus.offline:
        return 'No network connection';
      case NetworkStatus.checking:
        return 'Verifying connection';
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldPulse = widget.status == NetworkStatus.checking;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AethericTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator and text
          Row(
            children: [
              // Status icon with optional pulse
              shouldPulse
                  ? ScaleTransition(
                      scale: _pulseAnimation,
                      child: Icon(
                        _statusIcon,
                        size: 36,
                        color: _statusColor,
                      ),
                    )
                  : Icon(
                      _statusIcon,
                      size: 36,
                      color: _statusColor,
                    ),
              const SizedBox(width: 16),

              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusDescription,
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Metrics (if available)
          if (widget.status == NetworkStatus.optimal &&
              (widget.latencyMs != null || widget.region != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.latencyMs != null) ...[
                  Icon(Icons.speed_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.latencyMs}ms',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (widget.region != null) ...[
                  Icon(Icons.public_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    widget.region!,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Action buttons
          if (widget.status != NetworkStatus.checking) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Primary action (status-driven)
                if (widget.status == NetworkStatus.degraded ||
                    widget.status == NetworkStatus.offline)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onOptimize,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AethericTheme.aetherBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.status == NetworkStatus.offline
                            ? 'Troubleshoot'
                            : 'Optimize',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onOptimize,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Optimize',
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                // Secondary action
                OutlinedButton(
                  onPressed: widget.onShowDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Details', style: GoogleFonts.outfit()),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
