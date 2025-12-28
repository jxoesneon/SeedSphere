# Security Policy

## Supported Versions
Only the latest 2.0.x builds are currently supported with security updates as we transition from legacy.

| Version | Supported |
| :--- | :--- |
| 2.0.x | ✅ Yes |
| 1.x.x | ❌ No (Legacy) |

## Reporting a Vulnerability
We take the security of our federated network seriously. If you find a vulnerability regarding the P2P fabric, encryption (SEC-008), or data privacy, please do not open a public issue.

Instead, please send a detailed report to the maintainers (contact details in GitHub profile).

We aim to:
1. Acknowledge your report within 48 hours.
2. Provide an estimated timeline for a fix.
3. Coordinate a public disclosure once the fix is deployed across the swarm.

## Encryption Standard (SEC-008)
SeedSphere 2.0 utilizes Ed25519 for identity and XChaCha20-Poly1305 for data-at-rest. Any weaknesses found in the implementation of these primitives should be reported immediately.
