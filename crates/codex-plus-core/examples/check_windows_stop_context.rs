/// 只读诊断：check_windows_stop_context <桌面 exe> <调试端口> [--attached | 启动参数...]
#[cfg(windows)]
fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    anyhow::ensure!(args.len() >= 2, "需要桌面 exe 路径和调试端口");
    let port = args[1].parse::<u16>()?;
    anyhow::ensure!(port != 0, "调试端口不能为零");
    let extra_args = if args.get(2).is_some_and(|arg| arg == "--attached") {
        anyhow::ensure!(args.len() == 3, "--attached 不接受其他参数");
        None
    } else {
        Some(&args[2..])
    };
    codex_plus_core::watcher::check_windows_main_codex_stop_context(
        std::path::Path::new(&args[0]),
        Some(port),
        extra_args,
    )?;
    println!("停止上下文核验通过；未结束任何进程。");
    Ok(())
}

#[cfg(not(windows))]
fn main() {
    eprintln!("此诊断仅适用于 Windows。");
}
