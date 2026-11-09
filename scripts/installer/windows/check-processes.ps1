param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [switch]$AllowBackground
)
$ErrorActionPreference = 'Stop'

function Get-CodexLimitedProcessFacts([int]$ProcessId) {
    # WMI hides elevated-process details. Query the kernel with limited rights;
    # never request VM_READ, termination, debug privileges, or elevation.
    if (-not ('CodexInstallerProcessQuery' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
public sealed class CodexInstallerProcessQuery {
    public int ProcessId;
    public string Name;
    public string ExecutablePath;
    public string CommandLine;
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool QueryFullProcessImageName(IntPtr handle, uint flags, StringBuilder image, ref uint size);
    [DllImport("ntdll.dll")]
    static extern int NtQueryInformationProcess(IntPtr handle, int kind, IntPtr buffer, int size, out int returned);
    public static CodexInstallerProcessQuery Read(int pid) {
        IntPtr handle = OpenProcess(0x1000, false, pid);
        if (handle == IntPtr.Zero) return null;
        const int capacity = 128 * 1024;
        IntPtr buffer = IntPtr.Zero;
        try {
            var image = new StringBuilder(32768);
            uint imageSize = (uint)image.Capacity;
            if (!QueryFullProcessImageName(handle, 0, image, ref imageSize)) return null;
            buffer = Marshal.AllocHGlobal(capacity);
            int returned;
            // ProcessCommandLineInformation returns a local UNICODE_STRING.
            if (NtQueryInformationProcess(handle, 60, buffer, capacity, out returned) < 0) return null;
            int header = IntPtr.Size == 8 ? 16 : 8;
            int length = (ushort)Marshal.ReadInt16(buffer);
            IntPtr text = Marshal.ReadIntPtr(buffer, IntPtr.Size == 8 ? 8 : 4);
            long offset = text.ToInt64() - buffer.ToInt64();
            if (returned < header || returned > capacity || length % 2 != 0 ||
                offset < header || offset + length > returned) return null;
            return new CodexInstallerProcessQuery {
                ProcessId = pid,
                Name = Path.GetFileName(image.ToString()),
                ExecutablePath = image.ToString(),
                CommandLine = Marshal.PtrToStringUni(text, length / 2)
            };
        } finally {
            if (buffer != IntPtr.Zero) Marshal.FreeHGlobal(buffer);
            CloseHandle(handle);
        }
    }
}
'@
    }
    return [CodexInstallerProcessQuery]::Read($ProcessId)
}

function Get-CodexInstallerProcesses {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name='codex-plus-plus.exe' OR Name='codex-plus-plus-manager.exe' OR Name='codex-plus-plus.previous.exe'")
    foreach ($process in $processes) {
        if ($process.ExecutablePath -and $process.CommandLine) {
            $process
        } else {
            $limited = Get-CodexLimitedProcessFacts $process.ProcessId
            if ($limited) { $limited } else { $process }
        }
    }
}

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
        $processes = @(Get-CodexInstallerProcesses)
        if (Test-CodexInstallBlocked $processes $InstallDir $AllowBackground.IsPresent) { exit 1 }
        exit 0
    } catch {
        exit 2
    }
}
