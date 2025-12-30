import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';

/// The entry point/landing screen of the SeedSphere application.
///
/// Features a minimalist, premium aesthetic with a glassmorphic central card
/// set against a deep cosmic gradient. This screen serves as the gateway
/// to the [SwarmDashboard].
///
/// **Visual elements:**
/// - Radial gradient background (Deep Void)
/// - [AethericGlass] container for the main branding and CTA
/// - Custom typography using Google Fonts (Outfit)
/// - Integrated [HapticManager] feedback on button interaction
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen] widget.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background: Deep Void with a subtle radial gradient for depth
          RepaintBoundary(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [Color(0xFF0F172A), AethericTheme.deepVoid],
                ),
              ),
            ),
          ),

          // Main Call to Action (CTA) Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AethericGlass(
                borderRadius: 24,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Application Branding
                      Text(
                        'SEEDSPHERE 2.0',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'THE FEDERATED FRONTIER',
                        style: TextStyle(
                          color: Colors.white38,
                          letterSpacing: 4,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Primary Action: Navigate to Dashboard
                      ElevatedButton(
                        onPressed: () {
                          // Provide tactile feedback for the important navigation
                          HapticManager.heavy();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SwarmDashboard()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AethericTheme.aetherBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor:
                              AethericTheme.aetherBlue.withValues(alpha: 0.3),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          child: Text(
                            'ENTER SWARM',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secondary Action: Mobile Install (QR)
                      TextButton.icon(
                        onPressed: () => _showQrInstallDialog(context),
                        icon: const Icon(Icons.qr_code_rounded,
                            color: Colors.white60),
                        label: Text(
                          'INSTALL ON MOBILE',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrInstallDialog(BuildContext context) async {
    // Attempt to find a non-loopback IPv4 address
    String ip = '127.0.0.1';
    try {
      final interfaces = await java_io.NetworkInterface.list(
        type: java_io.InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        // Filter out VM/Docker adapters if possible, but first non-loopback is usually okay
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }
        if (ip != '127.0.0.1') break;
      }
    } catch (_) {}

    final url = 'stremio://$ip:7000/manifest.json';

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Mobile Install',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Scan this code with your phone camera to open SeedSphere in Stremio.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: GoogleFonts.firaCode(
                    color: AethericTheme.aetherBlue, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('DONE'),
            ),
          ],
        ),
      );
    }
  }
}
