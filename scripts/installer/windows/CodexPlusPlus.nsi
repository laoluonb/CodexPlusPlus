Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!define ROOT "..\..\.."

Name "Codex++"
OutFile "${ROOT}\dist\windows\CodexPlusPlus-${VERSION}-windows-x64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Codex++"
; 沿用旧安装目录登记，覆盖升级继续安装到原目录。
InstallDirRegKey HKCU "Software\Codex++" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Var ExistingInstall
Var HadDesktopEntry
Var LegacyDeleteTries

!define MUI_ICON "${ROOT}\apps\codex-plus-manager\src-tauri\icons\icon.ico"
!define MUI_UNICON "${ROOT}\apps\codex-plus-manager\src-tauri\icons\icon.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

; 主程序退出时负责恢复系统浏览器及清理后台服务，安装器不能强制结束进程。
; 每次检查后间隔 500ms；20 次仍未退出时提示从托盘退出，再重试或取消安装/卸载。
; 确认进程退出后再补 500ms 文件锁释放缓冲，避免 File/Delete 撞上残留锁（issue #2362）。
; 安装只等待本目录的主界面；独立 MCP 可继续服务当前 Codex。
; 卸载仍等待所有角色，避免删掉正在使用的工具。
!macro WAIT_FOR_PROCESS_EXIT UNFUNC BACKGROUND_ARG
  Function ${UNFUNC}
    InitPluginsDir
    SetOutPath "$PLUGINSDIR"
    !if "${UNFUNC}" == "WaitForProcessExit"
      File "check-processes.ps1"
    !else
      CopyFiles /SILENT "$INSTDIR\check-processes.ps1" "$PLUGINSDIR\check-processes.ps1"
    !endif
    StrCpy $2 0
  wait_loop:
    nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\check-processes.ps1" -InstallDir "$INSTDIR" ${BACKGROUND_ARG}'
    Pop $0
    Pop $9
    StrCmp $0 "0" wait_done 0
    IntOp $2 $2 + 1
    IntCmp $2 20 wait_prompt 0 wait_prompt
    Sleep 500
    Goto wait_loop
  wait_prompt:
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "无法确认 Codex++ 已退出。请从系统托盘退出 Codex++ 后重试；卸载时还需关闭 Codex，以释放后台工具。" /SD IDCANCEL IDRETRY wait_retry IDCANCEL wait_cancel
  wait_retry:
    StrCpy $2 0
    Goto wait_loop
  wait_cancel:
    SetErrorLevel 1
    Abort
  wait_done:
    Sleep 500
    SetOutPath "$INSTDIR"
  FunctionEnd
!macroend
!insertmacro WAIT_FOR_PROCESS_EXIT WaitForProcessExit "-AllowBackground"
!insertmacro WAIT_FOR_PROCESS_EXIT un.WaitForProcessExit ""

Section "Install"
  SetOutPath "$INSTDIR"
  ; 与 Rust 安装入口共用卸载登记，必须在本轮写登记之前判断是否覆盖升级。
  ReadRegStr $ExistingInstall HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "InstallLocation"
  StrCmp $ExistingInstall "" 0 existing_install_checked
  ReadRegStr $ExistingInstall HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Codex++" "InstallLocation"
  existing_install_checked:

  Call WaitForProcessExit

  ; 双程序版本升级时只保留统一应用。旧管理工具可能在本安装器被拉起后
  ; 才真正退出（更新入口本身就跑在 manager 里），WaitForProcessExit 看到
  ; 进程名消失时文件锁未必立刻释放，Delete 会静默失败；此处再轮询重试，
  ; 而不是一次失败就把整次安装 Abort 掉（issue #2460）。
  StrCpy $LegacyDeleteTries 0
  legacy_binary_delete_loop:
  Delete "$INSTDIR\codex-plus-plus-manager.exe"
  IfFileExists "$INSTDIR\codex-plus-plus-manager.exe" 0 legacy_binary_removed
    IntOp $LegacyDeleteTries $LegacyDeleteTries + 1
    IntCmp $LegacyDeleteTries 20 legacy_binary_delete_failed
    Sleep 500
    Goto legacy_binary_delete_loop
  legacy_binary_delete_failed:
    MessageBox MB_OK|MB_ICONSTOP "旧管理工具仍被占用。请退出 Codex++ 后重新安装。"
    Abort
  legacy_binary_removed:
  ; MCP 与界面共用 exe。已退出界面但 MCP 仍运行时，Windows 允许同目录重命名
  ; 映像，再写入新版；旧 MCP 继续使用原映像，不强杀当前 Codex 或它的工具。
  Delete "$INSTDIR\codex-plus-plus.exe"
  IfFileExists "$INSTDIR\codex-plus-plus.exe" 0 main_binary_ready
  Delete "$INSTDIR\codex-plus-plus.previous.exe"
  IfFileExists "$INSTDIR\codex-plus-plus.previous.exe" main_binary_busy 0
  ClearErrors
  Rename "$INSTDIR\codex-plus-plus.exe" "$INSTDIR\codex-plus-plus.previous.exe"
  IfErrors main_binary_busy main_binary_ready
  main_binary_busy:
    MessageBox MB_OK|MB_ICONSTOP "旧版 Codex 后台工具仍占用程序文件。请关闭 Codex 后重新安装。" /SD IDOK
    SetErrorLevel 1
    Abort
  main_binary_ready:
  File "${ROOT}\dist\windows\app\codex-plus-plus.exe"
  File "check-processes.ps1"
  ; 无运行中的旧 MCP 时可立即移除唯一备份；被占用则保留到下次安装/卸载。
  Delete "$INSTDIR\codex-plus-plus.previous.exe"

  ; 只迁移确实存在的桌面入口，用户删掉的入口在升级时仍不补建（issue #2376）。
  StrCpy $HadDesktopEntry 0
  IfFileExists "$DESKTOP\Codex++.lnk" desktop_entry_found 0
  IfFileExists "$DESKTOP\Codex++ 管理工具.lnk" desktop_entry_found 0
  IfFileExists "$DESKTOP\Codex++ 绠＄悊宸ュ叿.lnk" desktop_entry_found desktop_entry_checked
  desktop_entry_found:
  StrCpy $HadDesktopEntry 1
  desktop_entry_checked:
  Delete "$DESKTOP\Codex++.lnk"
  Delete "$DESKTOP\Codex++ 管理工具.lnk"
  Delete "$DESKTOP\Codex++ 绠＄悊宸ュ叿.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++ 管理工具.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++ 绠＄悊宸ュ叿.lnk"
  Delete "$SMPROGRAMS\Codex++\卸载 Codex++.lnk"

  StrCmp $ExistingInstall "" desktop_entry_create 0
  StrCmp $HadDesktopEntry 1 desktop_entry_create desktop_entry_done
  desktop_entry_create:
  CreateShortcut "$DESKTOP\Codex++.lnk" "$INSTDIR\codex-plus-plus.exe" "" "$INSTDIR\codex-plus-plus.exe"
  desktop_entry_done:
  CreateDirectory "$SMPROGRAMS\Codex++"
  CreateShortcut "$SMPROGRAMS\Codex++\Codex++.lnk" "$INSTDIR\codex-plus-plus.exe" "" "$INSTDIR\codex-plus-plus.exe"
  CreateShortcut "$SMPROGRAMS\Codex++\卸载 Codex++.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\codex-plus-plus.exe"

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\Codex++" "InstallDir" "$INSTDIR"
  ; 卸载项键名统一到运行时的正式键 CodexPlusPlus（issue #2339）。
  ; 运行时 install/windows.rs 把 Uninstall\CodexPlusPlus 当正式键、Uninstall\Codex++
  ; 当 legacy；这里若继续写 Codex++，经安装器装过又被管理工具碰过的机器会留下两条
  ; 卸载项，而运行时装过、之后走 NSIS 卸载的机器永远删不掉 CodexPlusPlus 那条。
  ; 写之前先清掉 legacy 键：存量用户靠这一步收尸，别删。
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Codex++"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "DisplayName" "Codex++"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "Publisher" "laoluonb"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "DisplayIcon" "$INSTDIR\codex-plus-plus.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus" "UninstallString" "$INSTDIR\uninstall.exe"

  ; 注册 codexplusplus:// 与 dreamskin:// URL 协议（issue #2354）。
  ; 键名与值同 codex-plus-core 的 install::windows::register_url_protocol 保持一致，
  ; 应用内"修复快捷方式"会以相同键幂等覆盖，两边互不冲突。
  WriteRegStr HKCU "Software\Classes\codexplusplus" "" "URL:Codex++ Import Protocol"
  WriteRegStr HKCU "Software\Classes\codexplusplus" "URL Protocol" ""
  WriteRegStr HKCU "Software\Classes\codexplusplus\shell\open\command" "" '"$INSTDIR\codex-plus-plus.exe" "%1"'
  WriteRegStr HKCU "Software\Classes\dreamskin" "" "URL:DreamSkin Community Theme Protocol"
  WriteRegStr HKCU "Software\Classes\dreamskin" "URL Protocol" ""
  WriteRegStr HKCU "Software\Classes\dreamskin\shell\open\command" "" '"$INSTDIR\codex-plus-plus.exe" "%1"'

  ; 仅迁移已经存在的自有开机项；不补建未启用的项，也不改 watcher.disabled。
  ; 新参数只打开界面，并由主程序检查禁用标记，旧 --debug-port 参数不再承担启动职责。
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "CodexPlusPlusWatcher"
  StrCmp $0 "" watcher_run_done 0
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "CodexPlusPlusWatcher" '"$INSTDIR\codex-plus-plus.exe" --autostart'
  watcher_run_done:
  IfFileExists "$SMSTARTUP\CodexPlusPlusWatcher.lnk" 0 watcher_shortcut_done
  CreateShortcut "$SMSTARTUP\CodexPlusPlusWatcher.lnk" "$INSTDIR\codex-plus-plus.exe" "--autostart" "$INSTDIR\codex-plus-plus.exe"
  watcher_shortcut_done:
SectionEnd

Section "Uninstall"
  Call un.WaitForProcessExit

  ; 删除主程序前恢复 config.toml：仍指向本机代理 127.0.0.1:57321 时清回官方配置，
  ; 否则卸载后官方 Codex 每次请求都 502（issue #406）。静默卸载同样执行；
  ; 主程序失败也以 0 退出，不阻塞卸载。
  IfFileExists "$INSTDIR\codex-plus-plus.exe" 0 +2
    ExecWait '"$INSTDIR\codex-plus-plus.exe" --codex-plus-uninstall-cleanup'

  Delete "$DESKTOP\Codex++.lnk"
  Delete "$DESKTOP\Codex++ 管理工具.lnk"
  Delete "$DESKTOP\Codex++ 绠＄悊宸ュ叿.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++.lnk"
  Delete "$SMPROGRAMS\Codex++\卸载 Codex++.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++ 管理工具.lnk"
  Delete "$SMPROGRAMS\Codex++\Codex++ 绠＄悊宸ュ叿.lnk"
  Delete "$SMPROGRAMS\Codex++\卸载 Codex++.lnk"
  RMDir "$SMPROGRAMS\Codex++"

  Delete "$INSTDIR\codex-plus-plus.exe"
  Delete "$INSTDIR\codex-plus-plus.previous.exe"
  Delete "$INSTDIR\codex-plus-plus-manager.exe"
  Delete "$INSTDIR\check-processes.ps1"

  ; NSIS 的 Delete 遇到被占用文件会静默失败，用户会误以为卸载干净。
  ; 残留检测提示用户先从托盘退出，避免“卸载后重装”继续失败（issue #2362）。
  IfFileExists "$INSTDIR\codex-plus-plus.exe" 0 +2
    MessageBox MB_OK|MB_ICONEXCLAMATION "Codex++ 仍被占用，未能删除。请从系统托盘退出 Codex++（或结束该进程）后重新卸载或安装。"

  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  ; 正式键 + legacy 键都删（issue #2339）：正式键是运行时写入的 CodexPlusPlus，
  ; legacy 是历史安装器和旧版运行时的 Codex++，存量机器上可能两条并存。
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexPlusPlus"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Codex++"
  DeleteRegKey HKCU "Software\Codex++"

  ; 清理安装器注册的 URL 协议（与 install::windows::uninstall_shortcuts 行为一致）。
  ; 仅删除本产品自有键，不影响用户其他协议注册。
  DeleteRegKey HKCU "Software\Classes\codexplusplus"
  DeleteRegKey HKCU "Software\Classes\dreamskin"
SectionEnd
