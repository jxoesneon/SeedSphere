# Contributing to SeedSphere

Thank you for your interest in SeedSphere! We are building a federated, P2P-native future for media discovery, and we welcome contributions that align with our vision of privacy and resilience.

## 1. Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## 2. Our Vision

Before contributing, please review our [Strategic Vision](.gemini/antigravity/brain/f21ac2a8-ea60-41de-b62a-458d906e1d94/Vision.md). We are moving from the legacy 1.0 architecture to a Flutter-native 2.0 swarm.

## 3. How to Contribute

### 3.1 Reporting Bugs

- Use the **Bug Report** template provided in GitHub issues.
- Include logs from the Native Gardener if available.
- Describe the hardware platform (e.g., Android TV version, iOS version).

### 3.2 Proposing Features

- Features should align with the "Zero-Cost Egress" and "P2P Authoritative" goals.
- Open a Discussion or a Feature Request issue before starting major work.

### 3.3 Development Flow

1. **Fork** the repository and create a branch from `Seedsphere-2.0`.
2. **Implement** your changes following the [UI/UX Design System](.gemini/antigravity/brain/f21ac2a8-ea60-41de-b62a-458d906e1d94/Design_System.md).
3. **Verify** your changes using the swarm simulation tools (to be implemented).
4. **Submit** a Pull Request using our standard template.

## 4. Coding Standards

- **Flutter**: Use Clean Architecture patterns. Avoid tight coupling between UI and P2P isolates.
- **Node/Bridge**: Use ESM for all new bridge logic.
- **Documentation**: Update the relevant PHD-level specifications if your change affects the architecture.
