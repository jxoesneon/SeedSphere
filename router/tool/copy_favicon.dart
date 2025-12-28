import 'dart:io';

void main() {
  final artifactPath =
      r'C:\Users\Eduardo\.gemini\antigravity\brain\f21ac2a8-ea60-41de-b62a-458d906e1d94\seedsphere_favicon.png';
  final portalPath =
      r'c:\Users\Eduardo\Documents\seedsphere\portal\favicon.png';

  try {
    File(artifactPath).copySync(portalPath);
    print('Favicon copied to $portalPath');
  } catch (e) {
    print('Error copying favicon: $e');
  }
}
