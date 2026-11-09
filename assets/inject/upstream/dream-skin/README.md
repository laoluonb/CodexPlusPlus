# 内置 Dream Skin 来源

- 上游：`Fei-Away/Codex-Dream-Skin`
- 版本：`v1.5.21`
- 提交：`6fc42df48a6a5365011f55cc349e20c038e56d1d`
- 同步日期：2026-11-09

Windows / macOS 的渲染器、样式和默认图片均与该提交的对应平台资源一致。
v1.5.21 相比 v1.5.20 未修改这些资源；本次同步更新内置版本、渲染器修订号和主题包兼容级别。
`theme.json` 继续保留本 fork 的去推广定制。

v1.5.21 的 Windows 修复位于独立版 PowerShell 启动及主题管理脚本，用于分离原生命令的标准输出与警告。
Codex++ 使用自身的 Rust 启动和主题导入流程，不调用这些脚本，因此未引入独立版启动器。

后续更新须同时核对平台资源、`DREAM_SKIN_PACKAGE_CLIENT_VERSION`、`DREAM_SKIN_RENDERER_REVISION`
和 `upstream_theme_assets` 中的资源摘要，并保留本 fork 的主题定制。
