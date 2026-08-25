use codex_plus_core::dream_skin_runtime::{
    DreamSkinRuntimeStatus, DreamSkinState, apply_dream_skin_live, macos_arch_name,
    parse_renderer_verification, windows_app_path_matches_registered_root,
};
use codex_plus_core::app_paths::resolve_saved_codex_app_dir;
use std::path::{Path, PathBuf};

#[test]
fn maps_rust_apple_silicon_arch_to_lipo_name() {
    assert_eq!(macos_arch_name("aarch64"), "arm64");
    assert_eq!(macos_arch_name("x86_64"), "x86_64");
}

#[test]
fn windows_identity_uses_native_package_api_without_powershell() {
    let source = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/dream_skin_runtime.rs"
    ))
    .unwrap();

    assert!(source.contains("registered_windows_packages"));
    assert!(!source.contains("Command::new(\"powershell\")"));
}

#[test]
fn windows_package_identity_is_refreshed_after_store_updates() {
    let source = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/app_paths.rs"
    ))
    .unwrap();
    let registered_packages = source
        .split("pub(crate) fn registered_windows_packages")
        .nth(1)
        .unwrap()
        .split("fn query_registered_windows_packages")
        .next()
        .unwrap();

    assert!(registered_packages.contains("query_registered_windows_packages()"));
    assert!(!registered_packages.contains("OnceLock"));
}

#[test]
fn live_apply_prefers_lightweight_update_and_keeps_full_injection_fallback() {
    let source = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/dream_skin_runtime.rs"
    ))
    .unwrap();
    let live_apply = source
        .split("pub async fn apply_dream_skin_live")
        .nth(1)
        .unwrap()
        .split("pub async fn pause_dream_skin_live")
        .next()
        .unwrap();

    assert!(live_apply.contains("dream_skin_live_update_probe_script"));
    assert!(live_apply.contains("dream_skin_live_update_script"));
    assert!(live_apply.contains("injection_script_with_settings"));
    assert!(!live_apply.contains("reload_dream_skin_live"));
    assert!(source.contains("reload_dream_skin_live"));
    assert!(source.contains("window.location.reload()"));
    assert!(!source.contains("Duration::from_millis(220)"));
}

#[test]
fn status_distinguishes_not_running_from_failed_verification() {
    let status = DreamSkinRuntimeStatus::not_running(true, false);

    assert_eq!(status.state, DreamSkinState::NotRunning);
    assert!(status.enabled);
    assert!(!status.paused);
    assert!(!status.live_applied);
    assert_eq!(status.checks[0].level.as_str(), "warning");
}

#[test]
fn changed_theme_status_requires_a_clean_restart() {
    let status = DreamSkinRuntimeStatus::pending_restart(true, false);

    assert_eq!(status.state, DreamSkinState::Warning);
    assert!(status.enabled);
    assert!(!status.paused);
    assert!(!status.live_applied);
    assert!(status.checks[0].message.contains("重启 Codex"));
}

#[test]
fn verification_treats_missing_optional_composer_as_warning() {
    let result = parse_renderer_verification(serde_json::json!({
        "installed": true,
        "version": "codex-plus:windows:custom",
        "stylePresent": true,
        "chromePresent": true,
        "chromePointerEvents": "none",
        "homeRoute": false,
        "homePresent": false,
        "visibleCardCount": 0,
        "projectButton": null,
        "composer": { "visible": false },
        "sidebar": { "visible": true },
        "documentOverflow": { "x": false, "y": false }
    }))
    .unwrap();

    assert_eq!(result.state, DreamSkinState::Pass);
    assert!(result.pass);
    assert!(
        result
            .checks
            .iter()
            .any(|check| check.id == "composer" && check.level.as_str() == "warning")
    );
}

#[test]
fn verification_accepts_managed_dream_skin_1_5_runtime_contract() {
    let result = parse_renderer_verification(serde_json::json!({
        "installed": true,
        "managedRuntime": true,
        "version": "1.5.14",
        "stylePresent": true,
        "chromePresent": false,
        "chromePointerEvents": "auto",
        "homeRoute": true,
        "homePresent": true,
        "homeReady": true,
        "visibleCardCount": 0,
        "composer": null,
        "sidebar": { "visible": true },
        "documentOverflow": { "x": false, "y": false }
    }))
    .unwrap();

    assert_eq!(result.state, DreamSkinState::Pass);
    assert!(result.pass);
    assert_eq!(result.version.as_deref(), Some("1.5.14"));
    assert!(
        result
            .checks
            .iter()
            .any(|check| check.id == "chrome" && check.level.as_str() == "pass")
    );
}

#[test]
fn windows_auto_detection_prefers_the_registered_store_package() {
    let source = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/app_paths.rs"
    ))
    .unwrap();
    let resolver = source
        .split("pub fn find_latest_codex_app_dir_default")
        .nth(1)
        .unwrap()
        .split("pub fn user_data_candidates")
        .next()
        .unwrap();

    let registered = resolver
        .find("find_latest_codex_app_dir_from_appx_package()")
        .unwrap();
    let directory_fallback = resolver
        .find("find_latest_codex_app_dir_from_roots")
        .unwrap();
    assert!(registered < directory_fallback);
}

#[test]
fn saved_store_path_tracks_the_current_registered_package_after_an_upgrade() {
    let saved = Path::new(
        r"C:\Program Files\WindowsApps\OpenAI.Codex_26.818.5229.0_x64__2p2nqsd0c76g0\app",
    );
    let current = PathBuf::from(
        r"C:\Program Files\WindowsApps\OpenAI.Codex_26.818.5345.0_x64__2p2nqsd0c76g0\app",
    );

    assert_eq!(
        resolve_saved_codex_app_dir(saved, Some(current.clone())),
        Some(current),
    );
}

#[test]
fn dream_skin_identity_uses_the_saved_path_resolver() {
    let source = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/dream_skin_runtime.rs"
    ))
    .unwrap();
    let identity_check = source
        .split("fn platform_identity_check")
        .nth(1)
        .unwrap()
        .split("fn platform_identity_check_for_dir")
        .next()
        .unwrap();

    assert!(identity_check.contains("resolve_codex_app_dir_with_saved"));
    assert!(!identity_check.contains("resolve_codex_app_dir(configured)"));
}

#[test]
fn verification_accepts_target_project_live_contract() {
    let result = parse_renderer_verification(serde_json::json!({
        "installed": true,
        "version": "codex-plus:windows:custom",
        "stylePresent": true,
        "chromePresent": true,
        "chromePointerEvents": "none",
        "homeRoute": true,
        "homePresent": true,
        "hero": { "visible": true, "width": 900, "height": 220 },
        "visibleCardCount": 4,
        "projectButton": { "visible": true },
        "composer": { "visible": true },
        "sidebar": { "visible": true },
        "documentOverflow": { "x": false, "y": false }
    }))
    .unwrap();

    assert_eq!(result.state, DreamSkinState::Pass);
    assert!(result.pass);
}

#[test]
fn bundled_skin_runtimes_use_their_expected_home_layout_contract() {
    for relative_path in [
        "assets/inject/upstream/dream-skin/windows/renderer-inject.js",
        "assets/inject/upstream/dream-skin/macos/renderer-inject.js",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative_path);
        let source = std::fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("failed to read {relative_path}: {error}"));
        assert!(
            source.contains("SELECTOR_CONTRACT") && source.contains("detectScope"),
            "missing scoped selector contract in {relative_path}"
        );
        assert!(
            source.contains("home-route") && !source.contains("data-dream-home-layout"),
            "unexpected legacy home layout contract in {relative_path}"
        );
    }

    for relative_path in [
        "assets/inject/upstream/cidala-tiger/windows/renderer-inject.js",
        "assets/inject/upstream/cidala-tiger/macos/renderer-inject.js",
        "assets/inject/upstream/snow-skin/renderer-inject.js",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative_path);
        let source = std::fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("failed to read {relative_path}: {error}"));
        assert!(
            source.contains("homeHasClassicChrome"),
            "missing home gate in {relative_path}"
        );
        assert!(
            source.contains("data-dream-home-layout"),
            "missing layout marker in {relative_path}"
        );
    }

    for relative_path in [
        "assets/inject/upstream/dream-skin/windows/dream-skin.css",
        "assets/inject/upstream/dream-skin/macos/dream-skin.css",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative_path);
        let source = std::fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("failed to read {relative_path}: {error}"));
        assert!(
            source.contains(":root[data-dream-skin=\"active\"]")
                && !source.contains("data-dream-home-layout"),
            "unexpected legacy home layout CSS in {relative_path}"
        );
    }

    for relative_path in [
        "assets/inject/upstream/cidala-tiger/windows/dream-skin.css",
        "assets/inject/upstream/cidala-tiger/macos/dream-skin.css",
        "assets/inject/upstream/snow-skin/dream-skin.css",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative_path);
        let source = std::fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("failed to read {relative_path}: {error}"));
        assert!(
            source.contains("data-dream-home-layout=\"soft\"")
                || (source.contains("data-dream-home-layout=\"structured\"")
                    && source.contains(":not([data-dream-home-layout=\"structured\"])")
                    )
                || source.contains("data-dream-home-layout=\\\"soft\\\"")
                || source.contains("data-dream-home-layout=\\\"structured\\\""),
            "missing soft layout CSS in {relative_path}"
        );
    }
}

#[test]
fn windows_identity_requires_a_path_inside_the_registered_package_root() {
    let root = std::path::Path::new(
        r"C:\Program Files\WindowsApps\OpenAI.Codex_26.707.1.0_x64__2p2nqsd0c76g0",
    );

    assert!(windows_app_path_matches_registered_root(root, root));
    assert!(windows_app_path_matches_registered_root(
        &root.join("app"),
        root
    ));
    assert!(!windows_app_path_matches_registered_root(
        std::path::Path::new(
            r"C:\Program Files\WindowsApps\OpenAI.Codex_26.707.1.0_x64__2p2nqsd0c76g0-copy\app",
        ),
        root,
    ));
}

#[tokio::test]
#[ignore = "requires a running Codex Desktop CDP renderer"]
async fn live_apply_keeps_the_running_renderer_available() {
    let debug_port = std::env::var("CODEX_PLUS_TEST_DEBUG_PORT")
        .expect("CODEX_PLUS_TEST_DEBUG_PORT is required")
        .parse()
        .expect("CODEX_PLUS_TEST_DEBUG_PORT must be a port");
    let helper_port = std::env::var("CODEX_PLUS_TEST_HELPER_PORT")
        .unwrap_or_else(|_| "57321".to_string())
        .parse()
        .expect("CODEX_PLUS_TEST_HELPER_PORT must be a port");
    let settings = codex_plus_core::settings::SettingsStore::default()
        .load()
        .expect("Dream Skin settings should load");
    codex_plus_core::dream_skin::sync_default_dream_skin_base_theme(
        true,
        &settings.codex_app_dream_skin_theme_config,
    )
    .expect("Dream Skin base theme should sync");

    let status = apply_dream_skin_live(debug_port, helper_port)
        .await
        .expect("live apply should succeed");
    assert!(status.live_applied, "live apply status: {status:?}");
    tokio::time::sleep(std::time::Duration::from_millis(800)).await;
    assert!(
        !codex_plus_core::cdp::list_targets(debug_port)
            .await
            .expect("Codex CDP should remain available")
            .is_empty()
    );
}
