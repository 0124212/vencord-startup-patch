#Requires -Version 5.1
<#
.SYNOPSIS
    Re-applies the Vencord patch to Discord at Windows logon (idempotent).

.DESCRIPTION
    Discord wipes the Vencord patch every time it self-updates, so this script
    re-patches on every logon using the official VencordInstallerCli:

      1. Ensures the CLI exists (downloads the latest release if missing).
      2. Self-updates the CLI ("already latest" is not an error).
      3. Stops running Discord processes to avoid patch races at boot.
      4. Patches every installed Discord branch (stable / ptb / canary).
      5. Logs everything to %LOCALAPPDATA%\Vencord\patch-vencord.log.

    Intended to run hidden at logon via patch-vencord.vbs (Startup folder).
    Safe to run manually any time - re-patching an already-patched install
    just unpatches and re-patches cleanly (exit 0).

    Upstream installer: https://github.com/Vencord/Installer
#>
[CmdletBinding()]
param(
    # Which branch to patch. "auto" patches every Discord flavour found on disk.
    [ValidateSet("auto", "stable", "ptb", "canary")]
    [string]$Branch = "auto",

    [switch]$NoSelfUpdate,
    [switch]$NoKillDiscord
)

$ErrorActionPreference = "Stop"
$CliDir  = Join-Path $env:LOCALAPPDATA "Vencord"
$CliPath = Join-Path $CliDir "VencordInstallerCli.exe"
$LogPath = Join-Path $CliDir "patch-vencord.log"
$CliDownloadUrl = "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe"

$BranchDirs = @{
    stable = "Discord"
    ptb    = "DiscordPTB"
    canary = "DiscordCanary"
}
$BranchProcesses = @{
    stable = "Discord"
    ptb    = "DiscordPTB"
    canary = "DiscordCanary"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

try {
    New-Item -ItemType Directory -Force $CliDir | Out-Null
    Write-Log "=== patch-vencord start (Branch=$Branch) ==="

    # 1. Ensure the CLI exists; fetch latest release if it somehow went missing.
    if (-not (Test-Path $CliPath)) {
        Write-Log "CLI not found at $CliPath, downloading latest release..." "WARN"
        Invoke-WebRequest -Uri $CliDownloadUrl -OutFile $CliPath -UseBasicParsing
        Write-Log ("Downloaded {0} bytes" -f (Get-Item $CliPath).Length)
    }

    # 2. Self-update. Exit 1 with "no update available" just means we are current.
    if (-not $NoSelfUpdate) {
        $upd = & $CliPath -update-self 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { Write-Log "CLI self-update applied." }
        else { Write-Log ("CLI self-update skipped (already latest). Details: " + $upd.Trim()) "WARN" }
    }
    else {
        Write-Log "Skipping CLI self-update (-NoSelfUpdate)"
    }

    # 3. Stop Discord first: patching under a running client (or racing its
    #    autostart at boot) is the classic way to end up unpatched.
    if (-not $NoKillDiscord) {
        $procs = Get-Process -Name @($BranchProcesses.Values) -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Log ("Stopping Discord processes: " + (($procs | Select-Object -ExpandProperty ProcessName | Sort-Object -Unique) -join ", "))
            $procs | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
        else {
            Write-Log "No Discord processes running"
        }
    }
    else {
        Write-Log "Skipping Discord shutdown (-NoKillDiscord)"
    }

    # 4. Resolve which branches to patch.
    if ($Branch -ne "auto") {
        $targets = @($Branch)
    }
    else {
        $targets = @($BranchDirs.Keys | Where-Object { Test-Path (Join-Path $env:LOCALAPPDATA $BranchDirs[$_]) })
    }
    if (-not $targets -or $targets.Count -eq 0) {
        Write-Log "No Discord install found under $env:LOCALAPPDATA" "ERROR"
        exit 1
    }
    Write-Log ("Target branches: " + ($targets -join ", "))

    # 5. Patch each branch. -install is idempotent (unpatch + re-patch).
    $failed = @()
    foreach ($b in $targets) {
        Write-Log "Patching branch '$b'..."
        $out = & $CliPath -install -branch $b 2>&1 | Out-String
        foreach ($ln in $out.Trim().Split("`n")) {
            $t = $ln.Trim()
            if ($t) { Write-Log "  cli: $t" }
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Branch '$b' patched OK"
        }
        else {
            Write-Log "Branch '$b' FAILED (exit $LASTEXITCODE)" "ERROR"
            $failed += $b
        }
    }

    if ($failed.Count -gt 0) {
        Write-Log ("Failed branches: " + ($failed -join ", ")) "ERROR"
        exit 1
    }
    Write-Log "=== patch-vencord done: all OK ==="
    exit 0
}
catch {
    Write-Log ("Unhandled error: " + $_.Exception.Message) "ERROR"
    exit 1
}
