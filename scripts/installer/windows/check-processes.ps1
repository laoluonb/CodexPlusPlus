param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [switch]$AllowBackground
)
$ErrorActionPreference = 'Stop'

function Test-CodexInstallBlocked {
    param($Processes, [string]$Directory, [bool]$BackgroundAllowed)
    $directoryPath = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    # Only first-argument roles handled before GUI startup in main.rs are safe.
    $roles = @(
        '--codex-plus-cu-mcp', '--codex-plus-browser-mcp', '--codex-plus-agent-mcp',
        '--codex-plus-claude-extension-mcp', '--codex-plus-extension-mcp',
        '--codex-plus-plugin-mcp', '--codex-plus-dsh-mcp',
        '--codex-plus-browser-turn-end', '--codex-plus-cu-cli',
        '--codex-plus-hook', '--codex-plus-host-call', '--codex-plus-multi-worker'
    )
    foreach ($process in $Processes) {
        # Missing elevated-process details must fail closed.
        if (-not $process.ExecutablePath) { return $true }
        $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($process.ExecutablePath))
        if (-not [string]::Equals($parent, $directoryPath, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not $BackgroundAllowed -or $process.Name -eq 'codex-plus-plus-manager.exe') {
            return $true
        }
        $command = [string]$process.CommandLine
        if ($command -notmatch '^(?:"[^"]+"|\S+)\s+(?<role>--[a-z-]+)(?:\s|$)' -or
            $roles -cnotcontains $Matches.role) {
            return $true
        }
    }
    return $false
}

# Dot-source for isolated tests. Never print users' full process command lines.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $processes = @(Get-CimInstance Win32_Process -Filter "Name='codex-plus-plus.exe' OR Name='codex-plus-plus-manager.exe' OR Name='codex-plus-plus.previous.exe'")
        if (Test-CodexInstallBlocked $processes $InstallDir $AllowBackground.IsPresent) { exit 1 }
        exit 0
    } catch {
        exit 2
    }
}
