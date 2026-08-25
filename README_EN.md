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

## Project Origins and Fork Changes

This repository is a fork of [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus) and continues to synchronize selected upstream changes. Its skin switching feature uses the original renderer and CSS from [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) v1.5.14, integrated into Codex++ and adapted for the current Codex desktop UI.

The main changes in this fork include:

- Per-model context window and auto-compaction threshold settings through Codex `model_catalog_json` configuration.
- Codex-Dream-Skin v1.5.14 renderer integration with compatibility fixes for the current home page, sidebar, project selector, and composer.
- DreamSkin community, theme marketplace, local themes, background images, live apply, screenshots, and runtime diagnostics. Community and marketplace lists display up to 12 themes per page.
- Runtime diagnostic fixes for already-active skins and stale saved Windows Store paths left behind after Codex upgrades.
- GitHub Release update checks, downloads, repository links, and issue links now use `laoluonb/CodexPlusPlus`.
- Selected upstream improvements for launch stability, provider configuration, session management, and DeepSeek tool history, while retaining this fork's compatibility fixes.
- Removal of promotional sites, recommendations, promotional presets, sponsorship entries, sponsor images, and promotional theme fields.

The Codex-Dream-Skin code remains under its MIT License; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The rest of this repository remains AGPL-3.0-only. Users are responsible for verifying licenses for third-party theme images and other assets.

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
