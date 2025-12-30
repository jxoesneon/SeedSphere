import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class SignalCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int seeders;
  final String? source;
  final String? magnet;
  final String? posterUrl;

  const SignalCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.seeders,
    this.source,
    this.magnet,
    this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
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
                      opacity: 0.6, // Dim it slightly for text readability
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
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AethericTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AethericTheme.success
                                    .withValues(alpha: 0.4),
                                width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt,
                                  size: 10, color: AethericTheme.success),
                              const SizedBox(width: 2),
                              Text(
                                '$seeders',
                                style: GoogleFonts.firaCode(
                                    fontSize: 10, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (source != null)
                          Text(
                            source!.toUpperCase(),
                            style: GoogleFonts.outfit(
                                fontSize: 9, color: Colors.white38),
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

  void _showDetails(BuildContext context) {
    HapticManager.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SignalDetailsSheet(
        title: title,
        magnet: magnet,
        seeders: seeders,
        source: source,
      ),
    );
  }
}

class _SignalDetailsSheet extends StatelessWidget {
  final String title;
  final String? magnet;
  final int seeders;
  final String? source;

  const _SignalDetailsSheet({
    required this.title,
    this.magnet,
    required this.seeders,
    this.source,
  });

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
                  title,
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
                  Icons.bolt, '$seeders Seeders', AethericTheme.success),
              const SizedBox(width: 12),
              _buildBadge(
                  Icons.source, source ?? 'Unknown', AethericTheme.aetherBlue),
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
              magnet ?? 'No magnet link available',
              style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white54),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: magnet == null ? null : () => _copyMagnet(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('COPY MAGNET'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: magnet == null ? null : () => _launchStremio(),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('LAUNCH'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AethericTheme.aetherBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _copyMagnet(BuildContext context) {
    if (magnet != null) {
      Clipboard.setData(ClipboardData(text: magnet!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Magnet copied to clipboard', style: GoogleFonts.outfit()),
          backgroundColor: AethericTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
      HapticManager.light();
      Navigator.pop(context);
    }
  }

  void _launchStremio() async {
    if (magnet == null) return;
    try {
      final uri = Uri.parse(magnet!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Try launching as text if standard launcher fails
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}
  }
}
