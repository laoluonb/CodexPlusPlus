# Codex++

<p align="center">
  <img src="docs/images/codex-plus-plus.png" alt="Codex++ icon" width="160">
</p>

<p align="center">
  <a href="README.md">中文</a> | English
</p>

<p align="center">
  <img alt="Release" src="https://img.shields.io/github/v/release/laoluonb/CodexPlusPlus">
  <img alt="Stars" src="https://img.shields.io/github/stars/laoluonb/CodexPlusPlus">
  <img alt="License" src="https://img.shields.io/github/license/laoluonb/CodexPlusPlus">
  <img alt="Rust" src="https://img.shields.io/badge/rust-1.85%2B-orange">
  <img alt="Tauri" src="https://img.shields.io/badge/tauri-2.x-24C8DB">
</p>

Codex++ is an external launcher and manager for the OpenAI Codex / ChatGPT desktop app. It uses Chromium DevTools Protocol and a local helper for provider switching, protocol conversion, session management, Dream Skin themes, and UI enhancements without modifying the official app's `app.asar` or installation files.

## Quick Start

Download the latest installer from [GitHub Releases](https://github.com/laoluonb/CodexPlusPlus/releases):

- Windows: `CodexPlusPlus-*-windows-x64-setup.exe`
- macOS Intel: `CodexPlusPlus-*-macos-x64.dmg`
- macOS Apple Silicon: `CodexPlusPlus-*-macos-arm64.dmg`

The installation provides two entry points:

- `Codex++`: silently starts the official desktop app with saved provider settings and enhancements.
- `Codex++ Manager`: manages providers, models, tools, sessions, themes, scripts, updates, and diagnostics.

## Features

| Area | Capabilities |
| --- | --- |
| Provider configuration | Official login, mixed API, pure API, aggregate providers, Responses / Chat Completions, model testing and discovery |
| Models and context | Per-model context windows and auto-compact thresholds through `model_catalog_json` |
| Session management | Local session scanning, bulk deletion, Markdown export, token usage, provider metadata sync, and backups |
| Codex enhancements | Plugin marketplace and model whitelist handling, session actions, paste fix, Chinese locale, fast startup, service tiers, Goals, and Stepwise |
| Dream Skin | Original Codex-Dream-Skin v1.5.14 renderer and styles with theme, background image, and live apply support |
| Development workflow | Project move, upstream worktrees, thread IDs, and Zed Remote project discovery |
| Maintenance | User scripts, app detection, shortcuts, Watcher, logs, diagnostics, health checks, and Release updates |

Every UI enhancement can be disabled independently. Real API keys remain local and should never be included in logs, screenshots, or issues.

## Updates

The manager checks GitHub Releases from `laoluonb/CodexPlusPlus` and downloads the installer for the current platform. The release workflow produces a Windows installer, macOS DMGs, and static `latest.json` metadata.

## Data Locations

- Codex config: `~/.codex/config.toml`
- Codex auth state: `~/.codex/auth.json`
- Codex local database: prefers `~/.codex/sqlite/*.db`, with legacy `~/.codex/state_5.sqlite` support
- Codex++ state and logs: `~/.codex-session-delete/`

## Development

```powershell
cd apps/codex-plus-manager
npm install
npm run check
npm test
npm run vite:build
cargo test --workspace
```

Build desktop packages with:

```powershell
npm run build
```

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE).

Repository: [laoluonb/CodexPlusPlus](https://github.com/laoluonb/CodexPlusPlus)
