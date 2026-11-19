# LerxnaOptimizer
optimize ur pc

A Windows 10 / 11 optimizer that **asks you Y/N before every change** and only asks about things that actually apply to your PC.

[![Windows tests](../../actions/workflows/test.yml/badge.svg)](../../actions/workflows/test.yml)

## How to run

1. Download the latest **`LerxnaOptimizer-vX.Y.zip`** from [Releases](../../releases) and extract it (right-click > Extract All)
2. Double-click **`Run-LerxnaOptimizer.bat`** and click **Yes** when Windows asks for Administrator

Nervous? Double-click **`Preview-LerxnaOptimizer.bat`** instead. It goes through everything the same way, but only **shows** every registry value, service and task it would change (with the current value next to it) and changes nothing. A copy of the preview is saved as a text file.

Other ways that also work:
- Right-click `LerxnaOptimizer.ps1` > **Run with PowerShell**
- From any PowerShell window:

```powershell
powershell -ExecutionPolicy Bypass -File .\LerxnaOptimizer.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\LerxnaOptimizer.ps1 -Preview
```

## Works on

| | |
|---|---|
| Windows 11 / Windows 10 (Home, Pro, Education, Enterprise, LTSC) | Fully supported |
| Windows 8.1 | Best effort - needs Windows Management Framework 5.1 installed (Win10/11-only options are hidden) |
| Windows Server 2016+ | Works; options that don't exist there (Store apps, Xbox) are hidden |
| Intel, AMD and ARM64 PCs, laptops and desktops, VMs | Supported |
| Windows 7 / 8 | Not supported - shows a message and exits |

It takes care of the usual problems by itself:
- Not run as admin: asks for Administrator rights and relaunches
- Opened in PowerShell 7 or 32-bit PowerShell: relaunches in 64-bit Windows PowerShell 5.1 (32-bit would save settings to the wrong place)
- Script on a network drive: copies itself locally first (admin windows can't see mapped drives)
- Script blocking (execution policy): bypassed for this run only by the launcher
- Missing Windows features or broken WMI: falls back or skips that part instead of crashing; any error returns you to the menu
- Small console window: tables shrink to fit
- Window stays open at the end so you can read the summary

Won't run on PCs where IT has locked PowerShell down (Constrained Language Mode - it tells you so) or in Windows S mode (Windows blocks PowerShell entirely there).

## What it does

### 1. Scans your PC first
Windows version, laptop vs desktop, CPU, GPU, RAM, SSD/HDD, free space, uptime, installed game launchers and everything that starts with Windows. It then gives you tips (e.g. "you haven't restarted in 9 days", "6 startup apps are safe to turn off") and hides options that don't apply (no Win11 tweaks on Win10, no Ultimate Performance on laptops, no OneDrive question if you don't have it, etc).

### 2. Startup & background apps scanner
Lists **everything** that auto-starts:
- Startup apps (registry Run keys + Startup folders)
- Microsoft Store app startup tasks
- Third-party scheduled tasks that run at logon / updaters
- Third-party services set to Automatic

For each one it shows if it's **running right now and how much RAM it uses**, who made it, and advice: `SAFE TO DISABLE`, `YOUR CHOICE` or `KEEP` (antivirus, audio/touchpad drivers, anti-cheat...). Leftovers pointing to deleted files are flagged too.

You can go one by one (Y/N), type numbers (`1,3,5-7`), or turn off everything marked safe. It can close the app right away too. It also shows what's using your RAM right now and lets you close those apps.

Startup items are turned off **the same way Task Manager does it** (nothing is deleted), so they show as "Disabled" in Task Manager and can be turned back on from the scanner or the Undo menu. Services are set to Manual, not Disabled.

### 3. 40+ tweaks in 8 categories
| Category | Examples |
|---|---|
| Performance | Visual effects, High / Ultimate Performance plan, hibernation, Fast Startup, SysMain, search indexing, background apps, Delivery Optimization, faster shutdown, BSOD auto-restart |
| Gaming | Game Mode, Game DVR off, game/audio priority, HAGS, mouse acceleration off, Sticky Keys popup off |
| Privacy & Telemetry | Telemetry + DiagTrack + telemetry tasks, activity history, advertising ID, typing data, Cortana/Bing search, Recall/Copilot, location, error reporting, Edge background |
| Ads, Tips & Suggestions | Start/lock screen/Settings ads, auto-installed apps, Widgets/News |
| Appearance & Explorer | Dark mode, file extensions/hidden files, recent files, taskbar, classic right-click menu, "End task" on taskbar |
| Apps & Bloatware | Built-in app remover (only lists apps you have), Xbox apps, background updaters/telemetry, OneDrive |
| Windows Update | No forced restarts, exclude drivers |
| Advanced | Terminals always as admin, block touch keyboard |

Three modes: **ask about everything**, **recommended** (auto-applies the safe ones, asks about the rest), or **express** (recommended only, no questions).

### 4. Junk cleanup & repair
Temp files, Windows Update cache, crash dumps, GPU shader caches, Recycle Bin, Delivery Optimization cache, DNS flush, DISM component cleanup, SFC/DISM repair. Shows how much space each one frees before asking.

### 5. Health checks
The PC report also checks:
- **Disk health**: SMART status, SSD wear and temperature for every drive
- **GPU driver age**: warns if it's over a year old, or if no real driver is installed
- **RAM speed**: warns if your RAM runs slower than it's rated for (XMP / EXPO turned off in the BIOS)

### 6. Safety
- **Preview mode** (`Preview-LerxnaOptimizer.bat`, `-Preview`, or option 8 in the menu): see every change before it happens
- **Every tweak can be undone on its own**. Before changing anything, the old value of every registry setting, service, scheduled task and power setting is saved. The Undo menu lists each tweak you applied, so you can undo all of them, pick some, or preview what undoing would do. The only things that can't be undone automatically (uninstalled apps, OneDrive) are labelled clearly.
- Offers to create a **System Restore point** before anything changes
- Everything is logged to `C:\ProgramData\LerxnaOptimizer\`

## Testing
Every push runs on a real Windows machine (GitHub Actions, `windows-latest`):
1. Syntax check in Windows PowerShell 5.1 and PowerShell 7, plus PSScriptAnalyzer
2. A self-test that scans the PC and previews every tweak (`-SelfTest`)
3. A round trip that **applies every tweak, undoes it, and checks that every single setting is back to its original value** (`-SelfTest -RoundTrip`)

## Releases
To publish a release: **Actions > Release > Run workflow**, type the version (e.g. `v2.2`), and it tests the script, builds the zip and publishes it on the Releases page. Pushing a `v*` tag does the same.

**Code signing (optional):** some antivirus programs are suspicious of unsigned "optimizer" scripts. To sign releases, get a code signing certificate (for example an OV certificate from a certificate authority, or Microsoft's Azure Trusted Signing), export it as a .pfx, and add two repository secrets: `SIGNING_CERT_BASE64` (the .pfx encoded as base64) and `SIGNING_CERT_PASSWORD`. The release workflow then signs `LerxnaOptimizer.ps1` automatically. Without them, releases are simply unsigned.
