# IAF Protocol Drive

**It's All Files — optional Drive exchange.** Formerly AgentOS Drive. The project name changed; existing packet formats, configuration names, base-version checks, and published archives remain compatible.

**Development preview 0.1.0-dev**, built on [IAF Protocol Portable 0.2.1](https://github.com/kyleillgen/IAF-Protocol/releases/tag/v0.2.1).

This separate variant adds an optional **Google Drive for desktop file exchange**. The base workspace and dispatcher stay local. No Google API credentials are required, and installation does not change your existing Drive settings or scheduled tasks.

## Start here

1. Install and verify the [base package](https://github.com/kyleillgen/IAF-Protocol/releases/tag/v0.2.1).
2. Follow [the Drive setup guide](packages/google-drive/README.md).
3. Test a harmless packet on two devices or through Drive on the web before sharing real task data.

The extension exports explicitly selected files into a dedicated Drive-managed folder. Each packet has a manifest and hashes. Import verifies the bytes and stages them for review outside the live workspace; it does not authorize tasks or start an agent.

## Current scope

Implemented: create/join an exchange, explicit selective export, bounded hash-verified import, read-only configuration check, and isolated tests for delayed/corrupt sync, path attacks and overwrite protection.

Not yet verified: live Google sync, remote permissions, offline-to-online behavior and signed-out operation. There is no automatic queue ingestion, polling, deletion propagation, Google Docs conversion or Drive API integration. This is a starter for technical testing, not an unattended synchronization service.

## Relationship to the base

This repository is a separate derivative with the clean base history and an `upstream` relationship documented in [UPSTREAM.md](UPSTREAM.md). Extension changes live in `packages/google-drive`; the portable source mirrors the compatible IAF rename in the core. The newer deployment profiles and operations code live in [IAF Protocol](https://github.com/kyleillgen/IAF-Protocol) and are not bundled here. See [rename compatibility](BRANDING.md).

[MIT license](LICENSE). See [contribution guidance](CONTRIBUTING.md). Never submit credentials, private task content or installed configuration.
