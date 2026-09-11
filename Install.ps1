#Requires -Version 5.1
<#
.SYNOPSIS
    One-time setup: installs patch-vencord into the user's Startup folder.

.DESCRIPTION
    Run once from this repo folder (right-click > Run with PowerShell, or
    `powershell -ExecutionPolicy Bypass -File .\Install.ps1`). Copies
    patch-vencord.vbs + patch-vencord.ps1 to the Startup folder, backing up
    any different files already there. Afterwards the patch runs hidden at
    every logon. See README.md.
#>
$ErrorActionPreference = "Stop"
$Startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"

foreach ($f in @("patch-vencord.vbs", "patch-vencord.ps1")) {
    $src = Join-Path $PSScriptRoot $f
    $dst = Join-Path $Startup $f
    if ((Test-Path $dst) -and ((Get-FileHash $src -ErrorAction Stop).Hash -ne (Get-FileHash $dst -ErrorAction Stop).Hash)) {
        $bak = "$dst.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Move-Item -Force $dst $bak
        Write-Host "Backed up existing $f -> $bak"
    }
    Copy-Item -Force $src $dst
    Write-Host "Installed $f -> $Startup"
}
Write-Host "Done. It runs hidden at next logon. Log: $env:LOCALAPPDATA\Vencord\patch-vencord.log"
