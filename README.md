# AgentOS Drive

**Development preview 0.1.0-dev**, built on [AgentOS Portable 0.2.1](https://github.com/kyleillgen/AgentOS-Portable/releases/tag/v0.2.1).

This separate variant adds an optional **Google Drive for desktop file exchange**. The base workspace and dispatcher stay local. No Google API credentials are required, and installation does not change your existing Drive settings or scheduled tasks.

## Start here

1. Install and verify the [base package](https://github.com/kyleillgen/AgentOS-Portable/releases/tag/v0.2.1).
2. Follow [the Drive setup guide](packages/google-drive/README.md).
3. Test a harmless packet on two devices or through Drive on the web before sharing real task data.

The extension exports explicitly selected files into a dedicated Drive-managed folder. Each packet has a manifest and hashes. Import verifies the bytes and stages them for review outside the live workspace; it does not authorize tasks or start an agent.

## Current scope

Implemented: create/join an exchange, explicit selective export, bounded hash-verified import, read-only configuration check, and isolated tests for delayed/corrupt sync, path attacks and overwrite protection.

Not yet verified: live Google sync, remote permissions, offline-to-online behavior and signed-out operation. There is no automatic queue ingestion, polling, deletion propagation, Google Docs conversion or Drive API integration. This is a starter for technical testing, not an unattended synchronization service.

## Relationship to the base

This repository is a separate derivative with the clean base history and an `upstream` relationship documented in [UPSTREAM.md](UPSTREAM.md). Changes to the extension live in `packages/google-drive`; base package files remain unchanged so future fixes can be merged from AgentOS-Portable.

[MIT license](LICENSE). See [contribution guidance](CONTRIBUTING.md). Never submit credentials, private task content or installed configuration.
