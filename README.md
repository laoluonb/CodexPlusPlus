# Codex++

<p align="center">
  <img src="docs/images/codex-plus-plus.png" alt="Codex++ 图标" width="160">
</p>

<p align="center">
  中文 | <a href="README_EN.md">English</a>
</p>

<p align="center">
  <img alt="Release" src="https://img.shields.io/github/v/release/laoluonb/CodexPlusPlus">
  <img alt="Stars" src="https://img.shields.io/github/stars/laoluonb/CodexPlusPlus">
  <img alt="License" src="https://img.shields.io/github/license/laoluonb/CodexPlusPlus">
  <img alt="Rust" src="https://img.shields.io/badge/rust-1.85%2B-orange">
  <img alt="Tauri" src="https://img.shields.io/badge/tauri-2.x-24C8DB">
</p>

Codex++ 是面向 OpenAI Codex / ChatGPT 桌面应用的外部启动器与管理工具。它通过 Chromium DevTools Protocol 和本地辅助服务提供供应商切换、协议转换、会话管理、Dream Skin 皮肤与界面增强，不修改官方应用的 `app.asar`，也不向安装目录写入补丁文件。

## 项目来源与本仓修改

本仓库是基于 [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus) 持续同步和修改的 fork。皮肤切换部分使用 [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) v1.5.14 的原版 renderer 与 CSS，并在 Codex++ 中完成集成和当前 Codex 桌面版兼容。

本仓库在上游基础上主要进行了以下修改：

- 增加按模型设置上下文窗口和自动压缩阈值的能力，并通过 `model_catalog_json` 写入 Codex 配置。
- 将皮肤切换替换为 Codex-Dream-Skin v1.5.14 的原版渲染代码，适配当前 Codex 首页、侧边栏、项目选择器和输入框结构。
- 增加 DreamSkin 社区、主题市场、本地主题、背景图片、实时应用、截图与运行诊断；社区和市场每页最多展示 12 个主题。
- 修复皮肤已生效但诊断误报的问题，包括 Codex Store 更新后保存路径仍指向残留旧版本目录的情况。
- GitHub Release 更新检测、下载地址、项目主页和问题反馈均改为从 `laoluonb/CodexPlusPlus` 获取。
- 同步上游的启动稳定性、供应商配置、会话管理、DeepSeek 工具历史等改进，并保留本仓库的兼容修复。
- 移除宣传站点、推荐内容、推广预设、赞助入口、赞助图片和主题中的推广字段。

Codex-Dream-Skin 的代码遵循其 MIT License，相关说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本仓库其余代码继续遵循 AGPL-3.0-only。第三方主题图片和素材的授权需由使用者自行确认。

## 快速使用

从 [GitHub Releases](https://github.com/laoluonb/CodexPlusPlus/releases) 下载最新版安装包：

- Windows：`CodexPlusPlus-*-windows-x64-setup.exe`
- macOS Intel：`CodexPlusPlus-*-macos-x64.dmg`
- macOS Apple Silicon：`CodexPlusPlus-*-macos-arm64.dmg`

安装后会有两个入口：

- `Codex++`：静默启动官方桌面应用，并加载已保存的供应商配置与增强功能。
- `Codex++ 管理工具`：管理供应商、模型、工具插件、会话、皮肤、脚本、更新和诊断。

首次使用建议先打开管理工具，确认应用路径和运行状态，再配置供应商与增强功能，最后从 `Codex++` 入口启动。

## 当前功能

| 分类 | 功能 |
| --- | --- |
| 供应商配置 | 官方登录、官方登录 + API、纯 API、聚合供应商、Responses / Chat Completions、模型测试与发现 |
| 模型与上下文 | 按模型配置上下文窗口和自动压缩阈值，生成 `model_catalog_json` |
| 会话管理 | 本地会话扫描、批量删除、Markdown 导出、Token 用量、Provider 元数据同步与备份 |
| Codex 增强 | 插件市场与模型白名单、会话操作、粘贴修复、中文界面、快速启动、服务层级、Goals、Stepwise |
| Dream Skin | 使用 Codex-Dream-Skin v1.5.14 的原版渲染器和样式，支持主题、背景图与实时应用 |
| 开发工作流 | 项目移动、Upstream worktree、线程 ID、Zed Remote 项目识别与打开 |
| 维护工具 | 用户脚本、应用检测、快捷方式、Watcher、日志、诊断、健康检查和 Release 更新 |

所有界面增强都可以单独关闭。关闭“Codex 增强”总开关后，Codex++ 仍可作为供应商和启动管理工具使用。

## 供应商模式

| 模式 | 用途 | 认证边界 |
| --- | --- | --- |
| 官方登录 | 只使用 ChatGPT / Codex 官方账号 | 清理自定义 provider 和 API Key，保留官方登录状态 |
| 官方登录 + API | 保留官方账号与插件入口，模型请求走兼容 API | API Key 写入 provider bearer token |
| 纯 API | 不依赖官方账号，完全使用自定义 Base URL / Key | 独立保存 `config.toml` 与 API Key |
| 聚合供应商 | 在多个普通 API 供应商之间路由 | 支持故障转移、会话轮转、请求轮转和权重轮转 |

真实 API Key 只保存在本机，请勿放入日志、截图或 issue。

## 自动更新

管理工具的“关于”页面会从 `laoluonb/CodexPlusPlus` 的 GitHub Release 检查更新并下载当前平台安装包。发布工作流会为 Release 生成 Windows 安装包、macOS DMG 和静态 `latest.json`。

## 数据位置

- Codex 配置：`~/.codex/config.toml`
- Codex 认证：`~/.codex/auth.json`
- Codex 本地数据库：优先 `~/.codex/sqlite/*.db`，兼容旧版 `~/.codex/state_5.sqlite`
- Codex++ 状态与日志：`~/.codex-session-delete/`

## 开发

```powershell
cd apps/codex-plus-manager
npm install
npm run check
npm test
npm run vite:build
cargo test --workspace
```

构建桌面安装包：

```powershell
npm run build
```

## 开源协议

本项目使用 [GNU Affero General Public License v3.0](LICENSE)。

项目地址：[laoluonb/CodexPlusPlus](https://github.com/laoluonb/CodexPlusPlus)
