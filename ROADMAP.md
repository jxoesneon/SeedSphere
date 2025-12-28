# SeedSphere Master Roadmap: 1.0.0 → 2.0.0 🚀

This roadmap outlines the systematic evolution of SeedSphere from a server-dependent aggregator to a **Federated Native Ecosystem**. Every phase is designed with PHD-level expertise in UI/UX, P2P networking, and cross-platform reliability.

---

## 🟢 PHASE 0: Structural Rebirth (Completed)
*Objective: Prepare the foundation by isolating legacy logic.*
- [x] **Project Reorganization**: Move all 1.0.0 code to `/legacy` subdirectory.
- [x] **Branch Strategy**: Establish `Seedsphere-2.0` as the development standard.
- [x] **Legacy Audit**: Perform deep-dive analysis into back-end aggregation and front-end management logic.

---

## 🟡 PHASE 1: The Native Foundation
*Objective: Establish the Flutter project and the P2P core.*

### 1.1 Native Gardener (Flutter)
- [ ] **Unified Workspace**: Initialize Flutter SDK for Desktop (Windows/Linux), Mobile (Android/iOS), and Web.
- [ ] **The "Aetheric Glass" Theme**: Implement the Gaussian-blur, bento-style design system with variable typography.
- [ ] **Background Sentinel**: Implement Android Foreground Services and iOS Background Fetch to maintain 24/7 IPFS connectivity.

### 1.2 P2P Core Integration
- [ ] **`dart_ipfs` Isolate**: Configure a dedicated compute isolate for the full-node IPFS implementation.
- [ ] **NAT Traversal**: Implement `p2plib` with STUN/TURN support to ensure peer-to-peer connectivity across restrictive firewalls.
- [ ] **HMAC Reputation System**: Build the Ed25519 signing layer for all network-broadcasted metadata.

---

## 🟠 PHASE 2: The Federated Swarm
*Objective: Decentralize signaling and stream discovery.*

### 2.1 P2P Logic Deployment
- [ ] **DHT Content Routing**: Implement Kademlia lookups for `ss:stream:vid` keys.
- [ ] **Gossipsub Sync**: Deploy the PubSub signaling client to allow Gardeners to "shout" stream results to nearby peers.
- [ ] **Bitswap Metadata Exchange**: Enable direct peer-to-peer block requests for cached stream lists.

### 2.2 Scraper Migration
- [ ] **Dart Scraper Port**: Re-implement Torrentio, YTS, EZTV, and other providers as high-performance Dart classes.
- [ ] **Logic Decoupling**: Ensure providers run locally in the Gardener to leverage the user's native IP context.

---

## 🔴 PHASE 3: Ecosystem Anchoring
*Objective: Bridge the federated network to the Stremio ecosystem.*

### 3.1 The SeedSphere Bridge
- [ ] **Cloudflare Edge Bridge**: Deploy a high-performance worker to translate IPFS CIDs into standard Stremio JSON responses.
- [ ] **Fly.io Bootstrap Node**: Refactor the current Greenhouse server into a lightweight P2P bootstrap and discovery node.
- [ ] **Pairing Protocol 2.0**: Implement zero-conf QR-code pairing between Mobile Gardeners and TV Seedlings.

### 3.2 Platform-Specific Excellence
- [ ] **Android TV Optimization**: High-contrast D-pad navigation and low-latency "Fastest Peer" selection.
- [ ] **iOS Eternal Player**: Configure the Bridge to automatically provide direct `externalUrl` links for VLC/Infuse compatibility.

---

## 💎 PHASE 4: Infinite 2.0.0 Release
*Objective: Global launch and verification of the zero-cost vision.*
- [ ] **Swarm Latency Audit**: Verify < 1.0s discovery time in a simulated 10,000-node network.
- [ ] **Zero-Cost Verification**: Confirm Fly.io usage remains within the free tier under high load.
- [ ] **Full Production Launch**: Official release of SeedSphere 2.0.0 "The Federated Frontier".

---

> [!TIP]
> **Architectural Philosophy**: "The infrastructure is the user, and the user is the infrastructure."
