import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignalCard extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final int seeders;
  final String? source;
  final String? magnet;
  final String? posterUrl;
  final String? id; // IMDb or meta ID for resolution

  const SignalCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.seeders,
    this.source,
    this.magnet,
    this.posterUrl,
    this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetails(context, ref),
      child: Container(
        width: 160,
        height: 220,
        margin: const EdgeInsets.only(right: 12),
        child: AethericGlass(
          borderRadius: 16,
          child: Stack(
            children: [
              // Background Image (Real Art) or Gradient (Fallback)
              if (posterUrl != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(posterUrl!),
                      fit: BoxFit.cover,
                      opacity: 0.6,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),

              // Gradient Overlay for Readability
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: magnet == null
                                ? Colors.white.withValues(alpha: 0.1)
                                : AethericTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: magnet == null
                                  ? Colors.white24
                                  : AethericTheme.success.withValues(
                                      alpha: 0.4,
                                    ),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                magnet == null
                                    ? Icons.hourglass_empty_rounded
                                    : Icons.bolt,
                                size: 10,
                                color: magnet == null
                                    ? Colors.white38
                                    : AethericTheme.success,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                magnet == null ? 'PENDING' : '$seeders',
                                style: GoogleFonts.firaCode(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (source != null)
                          Text(
                            source!.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: Colors.white38,
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Title
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    HapticManager.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SignalDetailsSheet(
        title: title,
        magnet: magnet,
        seeders: seeders,
        source: source,
        id: id,
      ),
    );
  }
}

class _SignalDetailsSheet extends ConsumerStatefulWidget {
  final String title;
  final String? magnet;
  final int seeders;
  final String? source;
  final String? id;

  const _SignalDetailsSheet({
    required this.title,
    this.magnet,
    required this.seeders,
    this.source,
    this.id,
  });

  @override
  ConsumerState<_SignalDetailsSheet> createState() =>
      _SignalDetailsSheetState();
}

class _SignalDetailsSheetState extends ConsumerState<_SignalDetailsSheet> {
  bool _isResolving = false;
  String? _resolvedMagnet;

  @override
  void initState() {
    super.initState();
    _resolvedMagnet = widget.magnet;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBadge(
                Icons.bolt,
                _resolvedMagnet == null ? 'N/A' : '${widget.seeders} Seeders',
                AethericTheme.success,
              ),
              const SizedBox(width: 12),
              _buildBadge(
                Icons.source,
                widget.source ?? 'Unknown',
                AethericTheme.aetherBlue,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Magnet Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              _resolvedMagnet ??
                  (widget.id != null
                      ? 'Magnet missing. Resolve via Swarm?'
                      : 'No magnet link available'),
              style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white54),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          if (_resolvedMagnet == null && widget.id != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResolving ? null : _handleResolve,
                icon: _isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.hub_rounded, size: 18),
                label: Text(
                  _isResolving ? 'RESOLVING...' : 'RESOLVE MAGNET VIA SWARM',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AethericTheme.aetherBlue.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: AethericTheme.aetherBlue,
                  side: BorderSide(
                    color: AethericTheme.aetherBlue.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resolvedMagnet == null
                        ? null
                        : () => _copyMagnet(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('COPY MAGNET'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resolvedMagnet == null
                        ? null
                        : () => _launchStremio(),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text('LAUNCH'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AethericTheme.aetherBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _handleResolve() async {
    setState(() => _isResolving = true);
    await HapticManager.medium();

    // 1. Trigger real P2P search
    if (widget.id != null) {
      ref.read(p2pManagerProvider).search(widget.id!);
    }

    // 2. Search is fire-and-forget, close immediately
    if (mounted) {
      setState(() => _isResolving = false);
      // Results will come via SSE stream in SwarmDashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search broadcasted to P2P Swarm for ${widget.title}'),
          backgroundColor: AethericTheme.aetherBlue,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _copyMagnet(BuildContext context) {
    if (_resolvedMagnet != null) {
      Clipboard.setData(ClipboardData(text: _resolvedMagnet!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Magnet copied to clipboard',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AethericTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
      HapticManager.light();
      Navigator.pop(context);
    }
  }

  void _launchStremio() async {
    if (_resolvedMagnet == null) return;
    try {
      final uri = Uri.parse(_resolvedMagnet!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}
  }
}
