param([string]$WorkDir = (Join-Path $env:TEMP ('codexpp-installer-test-' + [guid]::NewGuid())))
$ErrorActionPreference = 'Stop'
$checker = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../installer/windows/check-processes.ps1'))
. $checker -InstallDir $WorkDir

function Assert-Blocked($Processes, [bool]$Allow, [bool]$Expected, [string]$Label) {
    if ((Test-CodexInstallBlocked $Processes $WorkDir $Allow) -ne $Expected) {
        throw "Incorrect process classification: $Label"
    }
}
function New-TestProcess([string]$Arguments, [string]$Directory = $WorkDir) {
    [pscustomobject]@{
        Name = 'codex-plus-plus.exe'
        ExecutablePath = (Join-Path $Directory 'codex-plus-plus.exe')
        CommandLine = ('"' + (Join-Path $Directory 'codex-plus-plus.exe') + '" ' + $Arguments)
    }
}

Assert-Blocked @() $true $false 'no process'
Assert-Blocked @((New-TestProcess '')) $true $true 'GUI'
Assert-Blocked @((New-TestProcess '--autostart')) $true $true 'autostart GUI'
Assert-Blocked @((New-TestProcess '--show-update --codex-plus-extension-mcp')) $true $true 'role is not first'
Assert-Blocked @((New-TestProcess '--codex-plus-extension-mcp-fake')) $true $true 'unknown role'
Assert-Blocked @((New-TestProcess '--CODEX-PLUS-EXTENSION-MCP')) $true $true 'case does not match main.rs'
Assert-Blocked @((New-TestProcess '--codex-plus-extension-mcp --state-dir "C:\custom state"')) $true $false 'extension MCP'
Assert-Blocked @((New-TestProcess '--codex-plus-extension-mcp')) $false $true 'uninstall waits for MCP'
Assert-Blocked @((New-TestProcess '--codex-plus-browser-mcp'), (New-TestProcess '')) $true $true 'GUI and MCP'
Assert-Blocked @((New-TestProcess '' ($WorkDir + '-other'))) $true $false 'different install directory'
$unknown = New-TestProcess ''
$unknown.ExecutablePath = $null
Assert-Blocked @($unknown) $true $true 'unreadable image fails closed'
$unknown = New-TestProcess ''
$unknown.CommandLine = $null
Assert-Blocked @($unknown) $true $true 'unreadable command fails closed'
$legacy = New-TestProcess '--codex-plus-extension-mcp'
$legacy.Name = 'codex-plus-plus-manager.exe'
Assert-Blocked @($legacy) $true $true 'legacy manager never skipped'

# Replace a live fixture image without interrupting it.
# Only touch this new test directory and the process created below.
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$image = Join-Path $WorkDir 'codex-plus-plus.exe'
$backup = Join-Path $WorkDir 'codex-plus-plus.previous.exe'
Add-Type -TypeDefinition @'
public static class CodexInstallerFixture {
    public static void Main(string[] args) {
        System.Threading.Thread.Sleep(120000);
    }
}
'@ -OutputAssembly $image -OutputType WindowsApplication
$fixture = Start-Process -FilePath $image -ArgumentList '--codex-plus-extension-mcp' -WindowStyle Hidden -PassThru
try {
    $facts = Get-CimInstance Win32_Process -Filter "ProcessId=$($fixture.Id)"
    if (-not $facts) { throw 'Fixture process did not start' }
    $limited = Get-CodexLimitedProcessFacts $fixture.Id
    if (-not $limited) { throw 'Limited-rights kernel query failed' }
    Assert-Blocked @($limited) $true $false 'kernel query preserves first-argument MCP role'
    if ($limited.ExecutablePath -ne $image -or
        $limited.CommandLine -notlike '* --codex-plus-extension-mcp*') {
        throw 'Kernel query returned incorrect fixture identity'
    }
    Assert-Blocked @($facts) $true $false 'live MCP allows upgrade'
    Assert-Blocked @($facts) $false $true 'live MCP blocks uninstall'
    # Exercise the production script's real argument binding and exit code.
    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $checker -InstallDir $WorkDir -AllowBackground
    if ($LASTEXITCODE -ne 0) { throw 'Production checker rejected isolated MCP' }
    Move-Item -LiteralPath $image -Destination $backup
    Copy-Item -LiteralPath $backup -Destination $image
    if ($fixture.HasExited) { throw 'Upgrade interrupted original MCP' }
    if ((Get-FileHash -LiteralPath $image).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) {
        throw 'Replacement image differs'
    }
} finally {
    if (-not $fixture.HasExited) { $fixture.Kill(); $fixture.WaitForExit() }
    $fixture.Dispose()
}
Write-Output 'Windows installer process and live image replacement regressions passed.'
