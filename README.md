# vencord-startup-patch

Discord wipes the [Vencord](https://github.com/Vendicated/Vencord) patch every
time it self-updates. This pair of scripts re-applies it automatically at every
Windows logon, using the official CLI from
[Vencord/Installer](https://github.com/Vencord/Installer) (note: the repo moved
from `Vendicated/VencordInstaller`).

## Files

| File | What it does |
|---|---|
| `patch-vencord.vbs` | Hidden launcher that lives in the Startup folder. Runs the `.ps1` with no window and doesn't block logon. |
| `patch-vencord.ps1` | The real logic: ensures the CLI exists (downloads latest release if missing), self-updates it, stops running Discord clients, then patches every installed branch (`stable` / `ptb` / `canary`). Idempotent — re-running on an already-patched install just re-patches cleanly. |
| `Install.ps1` | One-time setup: copies the two files above into your Startup folder (backs up anything already there). |

## Install

```powershell
git clone https://github.com/0124212/vencord-startup-patch.git
cd vencord-startup-patch
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

Or manually copy `patch-vencord.vbs` + `patch-vencord.ps1` to
`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\`.

## Logs

Everything lands in `%LOCALAPPDATA%\Vencord\patch-vencord.log` — check there
first if Discord ever launches unpatched.

## Manual run

```powershell
powershell -ExecutionPolicy Bypass -File patch-vencord.ps1        # auto-detect branches
powershell -ExecutionPolicy Bypass -File patch-vencord.ps1 -Branch stable -NoSelfUpdate
```

## Uninstall

Delete `patch-vencord.vbs` and `patch-vencord.ps1` from the Startup folder.
Optionally unpatch via `VencordInstallerCli.exe -uninstall -branch stable`.

## Why not just the one-liner VBS?

The old approach (`VencordInstallerCli.exe -install -branch stable` in a bare
`.vbs`) breaks silently: a stale CLI, a running Discord racing the patch at
boot, or a missing CLI all fail with no trace. This version pins the workflow
to the current CLI (v1.4.0+, new `Vencord/Installer` home), self-updates,
handles running clients, auto-detects installed branches, and leaves a log.
