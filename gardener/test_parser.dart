import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'lib/core/parse_utils.dart';

void main() async {
  // Test basic parse
  final parsed = ParseUtils.parseReleaseInfo('magnet:?xt=urn:btih:123&dn=Obsession.2025.1080p.CAMRip.LAT.ENG.DUB.1XBET.mp4', 'Obsession.2025.1080p.CAMRip.LAT.ENG.DUB.1XBET.mp4');
  print('Parsed CAM: ' + parsed.toString());
  
  final parsed2 = ParseUtils.parseReleaseInfo('magnet:?xt=urn:btih:123', 'Obsession 2026 1080p CAM x264-DKS');
  print('Parsed TPB: ' + parsed2.toString());
}
