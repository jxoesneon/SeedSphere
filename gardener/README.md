# SeedSphere 2.0: The Federated Frontier

[![SeedSphere CI/CD](https://github.com/seedsphere/seedsphere/actions/workflows/cicd.yml/badge.svg)](https://github.com/seedsphere/seedsphere/actions/workflows/cicd.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)

SeedSphere is a high-performance, decentralized media discovery and streaming engine. Built on the IPFS protocol, it creates a federated frontier where users discover and share content without centralized bottlenecks.

## ✨ Key Features

- **Decentralized Core**: Built on `dart_ipfs` and custom P2P protocols for a truly federated experience.
- **Elite Performance**: Background isolate architecture ensures the UI remains fluid (60FPS) even during heavy swarm activity.
- **Aetheric UI**: A premium, glassmorphic design system with advanced micro-animations and custom shaders.
- **Cortex AI**: Intelligent Neuro-Link integration for personalized discovery.
- **Multi-Platform**: Native support for Windows, macOS, Linux, Android, iOS, and Web.
- **Debrid Integration**: Native support for Real-Debrid and other high-speed providers.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.2.0+)
- [Git](https://git-scm.com/downloads)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/seedsphere/seedsphere.git
   cd seedsphere/gardener
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

## 🛠 Architecture

SeedSphere uses a multi-layered architecture designed for security and scalability:

- **Core**: Security, Identity, and Stream Resolution logic.
- **P2P**: Background isolates handling DHT, Gossipsub, and Swarm connectivity.
- **Scrapers**: Extensible framework for multi-source metadata extraction.
- **UI**: Adaptive widgets and global state management via Riverpod.

## 🤝 Contributing

We welcome contributions from the community! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to get involved.

## 🛡 Security

For security concerns or to report vulnerabilities, please read our [SECURITY.md](SECURITY.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Built with ❤️ by the SeedSphere Team.
