# SeedSphere 2.0: The Federated Frontier

**Absolute Logic Parity Edition**

SeedSphere 2.0 is a decentralized, P2P-powered media discovery and streaming engine designed for the IPFS era. It achieves 100% feature parity with the legacy SeedSphere 1.0 while rebuilding the core on a robust, scalable architecture.

## 🚀 Key Features

### Core Parity (100% Achieved)
- **Aggregated Search**: Unified search across multiple providers (Torrentio, YTS, etc.).
- **Real-time Swarm**: Live P2P swarm scraping and health checks.
- **Smart Caching**: Cloudflare KV-backed SWR caching for instant results.
- **Metadata Normalization**: Advanced SxxEyy detection and title cleaning.

### Phase 2.2 Enhancements (New!)
- **Expanded Providers**:
  - **EZTV**: TV Series (API integration)
  - **Nyaa**: Anime (HTML scraping + Cinemeta)
  - **1337x**: General (Multi-mirror support)
  - **PirateBay**: Classic (HTML parsing)
- **Subtitle Support**: OpenSubtitles integration via Bridge.
- **Email Notifications**: System alerts via SMTP/Brevo.
- **Aetheric Glass UI**: Premium glassmorphic design system.

## 🏗️ Architecture

- **Gardener (Flutter)**: The client application. Handles UI, local scraping, and P2P logic.
- **Router (Dart)**: The bootstrap node. Manages swarm health, telemetry, and email services.
- **Bridge (Cloudflare Worker)**: The edge API. Handles caching, subtitle proxying, and metadata enhancement.

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK 3.22+
- Dart SDK 3.4+
- Docker (optional, for Router)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/seedsphere/seedsphere.git
   ```

2. **Run Gardener (Client)**
   ```bash
   cd gardener
   flutter pub get
   flutter run
   ```

3. **Run Router (Server)**
   ```bash
   cd router
   dart pub get
   dart run bin/server.dart
   ```

## 🔒 Security
SeedSphere 2.0 uses Ed25519 signing for all critical communications and implements strict strict content verification policies.

---
*Federated Frontier • 2026*
