import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class DebugLogsScreen extends ConsumerStatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  ConsumerState<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends ConsumerState<DebugLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // If we are within 100 pixels of the bottom, keep auto-scrolling
      setState(() {
        _autoScroll = maxScroll - currentScroll <= 100;
      });
    }
  }

  Future<void> _generateReport() async {
    final p2p = ref.read(p2pManagerProvider);
    final security = SecurityManager();
    final sharedSecret = await security.getSharedSecret();
    final metadata = p2p.diagnosticMetadata;

    final report = StringBuffer();
    report.writeln('=== SEEDSPHERE DIAGNOSTIC REPORT ===');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln(
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    report.writeln('Flutter Version: ${kDebugMode ? 'Debug' : 'Release'}');
    report.writeln('---');
    report.writeln('P2P Status: ${metadata['status']}');
    report.writeln('Peer ID: ${metadata['peerId']}');
    report.writeln('Listen Addresses: ${metadata['addresses']}');
    report.writeln('Peers Available: ${p2p.peerCount.value}');
    report.writeln('---');
    report.writeln(
      'Auth State: ${sharedSecret != null ? 'Authenticated' : 'Unlinked'}',
    );
    report.writeln('Gardener ID: ${p2p.gardenerId}');
    report.writeln('---');
    report.writeln('LAST 100 LOGS:');

    final logs = DebugLogger.logs.reversed.take(100).toList().reversed;
    for (final e in logs) {
      final time = DateFormat('HH:mm:ss.SSS').format(e.timestamp);
      final cat = e.category != null ? '[${e.category}] ' : '';
      report.writeln('[$time] $cat${e.levelLabel}: ${e.message}');
    }

    await Clipboard.setData(ClipboardData(text: report.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Full Diagnostic Report copied to clipboard'),
          backgroundColor: AethericTheme.aetherBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyLogs() {
    final filteredLogs = DebugLogger.logs.where((e) {
      if (_selectedCategory == null) return true;
      return e.category == _selectedCategory;
    });

    final allLogs = filteredLogs
        .map((e) {
          final time = DateFormat('HH:mm:ss.SSS').format(e.timestamp);
          final cat = e.category != null ? '[${e.category}] ' : '';
          return '[$time] $cat${e.levelLabel}: ${e.message}${e.error != null ? '\nError: ${e.error}' : ''}';
        })
        .join('\n');

    Clipboard.setData(ClipboardData(text: allLogs)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filtered logs copied to clipboard',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AethericTheme.aetherBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Color _getLevelColor(int level) {
    if (level >= 1200) return Colors.purpleAccent; // Security
    if (level >= 1000) return Colors.redAccent; // Error
    if (level >= 900) return Colors.orangeAccent; // Warning
    if (level >= 800) return Colors.blueAccent; // Info
    return Colors.white54; // Debug
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('DEBUG LOGS', style: GoogleFonts.outfit(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.assignment_rounded,
              color: AethericTheme.aetherBlue,
            ),
            tooltip: 'Generate Diagnostic Report',
            onPressed: _generateReport,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            tooltip: 'Copy filtered logs',
            onPressed: _copyLogs,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
            ),
            tooltip: 'Clear logs',
            onPressed: () => DebugLogger.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: DebugLogger.logsNotifier,
              builder: (context, logs, _) {
                final filteredLogs = logs.where((e) {
                  if (_selectedCategory == null) return true;
                  return e.category == _selectedCategory;
                }).toList();
                if (_autoScroll && _scrollController.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  });
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NO LOGS RECORDED',
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[index];
                    final time = DateFormat(
                      'HH:mm:ss.SSS',
                    ).format(entry.timestamp);
                    final color = _getLevelColor(entry.level);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '[$time]',
                                style: GoogleFonts.firaCode(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (entry.category != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    entry.category!,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  entry.levelLabel,
                                  style: GoogleFonts.outfit(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.message,
                            style: GoogleFonts.firaCode(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                          if (entry.error != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ERROR: ${entry.error}',
                              style: GoogleFonts.firaCode(
                                color: Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _autoScroll
          ? null
          : FloatingActionButton.small(
              backgroundColor: AethericTheme.aetherBlue,
              onPressed: () {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(
                Icons.arrow_downward_rounded,
                color: Colors.black,
              ),
            ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['NET', 'DHT', 'PERF', 'AUTH', 'UI'];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip(null, 'ALL'),
          ...categories.map((c) => _filterChip(c, c)),
        ],
      ),
    );
  }

  Widget _filterChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.outfit(fontSize: 11)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
        },
        selectedColor: AethericTheme.aetherBlue.withValues(alpha: 0.3),
        backgroundColor: Colors.white10,
        labelStyle: TextStyle(
          color: isSelected ? AethericTheme.aetherBlue : Colors.white60,
        ),
      ),
    );
  }
}
