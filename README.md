# LerxnaOptimizer
optimize ur pc

A Windows 10 / 11 optimizer that **asks you Y/N before every change** and only asks about things that actually apply to your PC.

## How to run

1. Download **both** `Run-LerxnaOptimizer.bat` and `LerxnaOptimizer.ps1` into the same folder (if you downloaded a .zip, extract it first)
2. Double-click **`Run-LerxnaOptimizer.bat`** and click **Yes** when Windows asks for Administrator

Other ways that also work:
- Right-click `LerxnaOptimizer.ps1` > **Run with PowerShell**
- From any PowerShell window:

```powershell
powershell -ExecutionPolicy Bypass -File .\LerxnaOptimizer.ps1
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

### 5. Safety
- Offers to create a **System Restore point** before anything changes
- **Undo menu**: turn startup items back on, fix the touch keyboard block, undo terminals-as-admin, open System Restore
- Everything is logged to `C:\ProgramData\LerxnaOptimizer\`
