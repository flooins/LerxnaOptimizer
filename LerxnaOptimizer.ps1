# ============================================================
#            Lerxna Optimizer v2.1 - Windows Setup Script
#                    Run as Administrator
# ============================================================
#  Usage
#   .\LerxnaOptimizer.ps1             normal (asks before every change)
#   .\LerxnaOptimizer.ps1 -Preview    shows every change it WOULD make,
#                                     changes nothing
#   .\LerxnaOptimizer.ps1 -SelfTest   automated test, used by GitHub
#                                     Actions (add -RoundTrip to apply
#                                     every tweak, undo it and verify)
#
#  What's new in v2.1
#   - Every tweak can be undone on its own: old values are saved
#     before anything is changed
#   - Preview mode
#
#  What's new in v2.0
#   - Scans your PC first (Windows version, CPU/GPU, RAM, disk,
#     laptop/desktop, installed games, startup apps) and only
#     asks about things that actually apply to you
#   - Startup & background apps scanner: lists everything that
#     starts with Windows, shows what's running and how much RAM
#     it uses, tells you what's safe to turn off, and turns
#     auto-start off the same way Task Manager does (undo-able)
#   - 40+ tweaks in 8 categories, each with its own Y/N
#   - 3 modes: ask about everything / recommended / express
#   - Bloat app remover that only lists apps you have installed
#   - Junk file cleanup, restore point, undo menu, log file
# ============================================================

param(
    [switch]$Preview,
    [switch]$SelfTest,
    [switch]$RoundTrip
)

# ------------------------------------------------------------
# Compatibility checks + relaunch
# This part only uses very basic PowerShell so it can show a clear
# message on any Windows / PowerShell version instead of crashing.
# ------------------------------------------------------------
function Stop-WithMessage {
    param([string]$Message)
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Red
    Write-Host ""
    if (-not $SelfTest) { try { Read-Host "  Press Enter to close" | Out-Null } catch {} }
    exit 1
}

if ($env:OS -ne 'Windows_NT') { Stop-WithMessage "Lerxna Optimizer only runs on Windows." }

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Stop-WithMessage ("This needs Windows PowerShell 5.1 (built into Windows 10 and 11). You have version {0}. On Windows 8.1, install 'Windows Management Framework 5.1' from Microsoft first." -f $PSVersionTable.PSVersion)
}

$OSBuild = 0
try { $OSBuild = [int](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).CurrentBuildNumber } catch {}
if (-not $OSBuild) { $OSBuild = [Environment]::OSVersion.Version.Build }
if ($OSBuild -lt 9600) {
    Stop-WithMessage "Windows 7 and 8 are not supported (they're missing tools this optimizer needs). Windows 8.1, 10 and 11 are supported."
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Stop-WithMessage "PowerShell is locked down on this PC (Constrained Language Mode - usually set by a school or work IT department). Lerxna Optimizer can't run here."
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$IsCore    = $PSVersionTable.PSEdition -eq 'Core'
# 32-bit PowerShell on 64-bit Windows writes registry settings to the wrong place
$Is32On64  = [Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess

if ($SelfTest) {
    # Automated test: never relaunch (that would hide the result); just require admin
    if (-not $IsAdmin) { Stop-WithMessage "-SelfTest must run as Administrator." }
} elseif (-not $IsAdmin -or $IsCore -or $Is32On64) {
    # Relaunch in 64-bit Windows PowerShell 5.1, as Administrator
    $psExe = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($Is32On64) { $psExe = Join-Path $env:windir 'Sysnative\WindowsPowerShell\v1.0\powershell.exe' }
    if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }

    $scriptPath = $PSCommandPath
    if ($scriptPath) {
        # The Administrator window can't see mapped network drives, so copy the script locally first
        $onNetwork = $scriptPath.StartsWith('\\')
        if (-not $onNetwork) {
            try { $onNetwork = ([System.IO.DriveInfo]::new($scriptPath.Substring(0, 1))).DriveType -eq 'Network' } catch {}
        }
        if ($onNetwork) {
            try {
                $localCopy = Join-Path $env:TEMP 'LerxnaOptimizer.ps1'
                Copy-Item -LiteralPath $scriptPath -Destination $localCopy -Force -ErrorAction Stop
                $scriptPath = $localCopy
            } catch {}
        }

        $launchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
        if ($Preview) { $launchArgs += '-Preview' }
        try {
            if ($IsAdmin) { Start-Process -FilePath $psExe -ArgumentList $launchArgs -ErrorAction Stop }
            else          { Start-Process -FilePath $psExe -ArgumentList $launchArgs -Verb RunAs -ErrorAction Stop }
        } catch {
            Stop-WithMessage "Lerxna Optimizer needs Administrator rights. Right-click it and choose 'Run as administrator' (or click Yes on the prompt)."
        }
        exit
    }

    # Pasted into a console instead of run from a file
    if (-not $IsAdmin) { Stop-WithMessage "Please open PowerShell as Administrator and run Lerxna Optimizer again." }
    Write-Host "  Note: for best results run this in 64-bit Windows PowerShell 5.1." -ForegroundColor Yellow
}

$ProgressPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'Lerxna Optimizer v2.1' } catch {}
# Make the window wide enough for the tables (silently ignored where not possible, e.g. Windows Terminal)
try {
    $raw = $Host.UI.RawUI
    if ($raw.WindowSize.Width -lt 120 -and $raw.MaxPhysicalWindowSize.Width -ge 120) {
        if ($raw.BufferSize.Width -lt 120) { $raw.BufferSize = New-Object System.Management.Automation.Host.Size 120, ([Math]::Max($raw.BufferSize.Height, 3000)) }
        $raw.WindowSize = New-Object System.Management.Automation.Host.Size 120, $raw.WindowSize.Height
    }
} catch {}

# ------------------------------------------------------------
# Globals
# ------------------------------------------------------------
$Script:Version   = '2.1'
$Script:DataDir   = Join-Path $env:ProgramData 'LerxnaOptimizer'
try { New-Item -ItemType Directory -Path $Script:DataDir -Force -ErrorAction Stop | Out-Null }
catch { $Script:DataDir = $env:TEMP }
$Script:LogFile    = Join-Path $Script:DataDir ("log_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$Script:BackupFile = Join-Path $Script:DataDir 'startup_backup.json'
$Script:JournalFile = Join-Path $Script:DataDir 'tweaks_backup.json'   # old values of every tweak, for Undo

# Preview mode: show what would change, change nothing
$Script:Preview        = [bool]$Preview
$Script:NonInteractive = [bool]$SelfTest
$Script:PreviewLog     = New-Object System.Collections.Generic.List[string]
$Script:Previewed      = New-Object System.Collections.Generic.List[string]
$Script:CurrentRecord  = $null    # the tweak whose changes are being recorded right now

$Script:Applied  = New-Object System.Collections.Generic.List[string]
$Script:Skipped  = New-Object System.Collections.Generic.List[string]
$Script:Failed   = New-Object System.Collections.Generic.List[string]
$Script:StartupChanges       = 0
$Script:NeedsExplorerRestart = $false
$Script:NeedsReboot          = $false
$Script:TweakCancelled       = $false
$Script:SummaryShownAt       = -1
$Script:Provisioned          = $null
$Script:LastScan             = @()

$Script:ApprovedHKCU = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$Script:ApprovedHKLM = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$Script:AdvKey       = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$Script:UninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# Processes the scanner will never offer to close
$Script:ProtectedProcs = @(
    'System','Idle','Registry','smss','csrss','wininit','winlogon','services','lsass','LsaIso',
    'svchost','dwm','explorer','fontdrvhost','sihost','ctfmon','RuntimeBroker','SearchHost',
    'SearchApp','SearchIndexer','StartMenuExperienceHost','ShellExperienceHost','TextInputHost',
    'MsMpEng','NisSrv','MpDefenderCoreService','SecurityHealthService','SecurityHealthSystray',
    'audiodg','conhost','powershell','pwsh','WindowsTerminal','OpenConsole','Memory Compression',
    'spoolsv','taskhostw','dllhost','WmiPrvSE','smartscreen','ApplicationFrameHost','SystemSettings',
    'LockApp','backgroundTaskHost','WUDFHost','dasHost','SgrmBroker','CompPkgSrv','MoUsoCoreWorker',
    'TiWorker','TrustedInstaller','UserOOBEBroker','SecurityHealthHost','winlogon','csrss',
    'NVDisplay.Container','atiesrxx','atieclxx','amdfendrsr','igfxEM','RtkAudUService64'
)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Log {
    param([string]$Message)
    try { Add-Content -Path $Script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ErrorAction SilentlyContinue } catch {}
}

function Pink  { param($msg) Write-Host $msg -ForegroundColor Magenta }
function Done  { param($msg) Write-Host "   [OK] $msg" -ForegroundColor Green;    Write-Log "OK: $msg" }
function Skip  { param($msg) Write-Host "   [--] Skipped: $msg" -ForegroundColor DarkGray; Write-Log "SKIP: $msg" }
function Warn  { param($msg) Write-Host "   [!!] $msg" -ForegroundColor Yellow;   Write-Log "WARN: $msg" }
function Info  { param($msg) Write-Host "   $msg" -ForegroundColor Gray }

function Section {
    param([string]$Title)
    Write-Host ""
    Pink "  =================================================="
    Pink "   $Title"
    Pink "  =================================================="
}

function Get-Short {
    param([string]$Text, [int]$Max)
    if (-not $Text) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    return $Text.Substring(0, $Max - 3) + '...'
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N0} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

# Yes/No question. Tag: REC (green), CAUTION (yellow), CHOICE (cyan)
function Ask {
    param([string]$Question, [string]$Tag = '', [string]$Note = '')
    if ($Script:NonInteractive) { Write-Log "ASK (auto-no): $Question"; return $false }
    Write-Host ""
    Write-Host "  >> $Question" -ForegroundColor Magenta -NoNewline
    switch ($Tag) {
        'REC'     { Write-Host "  [Recommended]" -ForegroundColor Green -NoNewline }
        'CAUTION' { Write-Host "  [Caution]"     -ForegroundColor Yellow -NoNewline }
        'CHOICE'  { Write-Host "  [Your choice]" -ForegroundColor Cyan -NoNewline }
    }
    Write-Host ""
    if ($Note) {
        foreach ($line in ($Note -split "`n")) { Write-Host "     $line" -ForegroundColor DarkGray }
    }
    while ($true) {
        Write-Host "     [Y/N]: " -ForegroundColor White -NoNewline
        $r = ([string](Read-Host)).Trim()
        if ($r -match '^(y|yes)$') { return $true }
        if ($r -match '^(n|no)$')  { return $false }
        Write-Host "     Please type Y or N." -ForegroundColor DarkYellow
    }
}

# Menu choice - returns the (upper-case) choice
function Read-Choice {
    param([string]$Prompt, [string[]]$Valid)
    if ($Script:NonInteractive) { return '0' }
    while ($true) {
        Write-Host ""
        Write-Host "  $Prompt " -ForegroundColor White -NoNewline
        $r = ([string](Read-Host)).Trim().ToUpper()
        if ($Valid -contains $r) { return $r }
        Write-Host "  Invalid choice, try again." -ForegroundColor DarkYellow
    }
}

# Turns "1,3,5-7" (or "all") into a list of numbers between 1 and Max
function Parse-Selection {
    param([string]$Text, [int]$Max)
    $result = New-Object System.Collections.Generic.List[int]
    if ($Text -match '^\s*(all|\*)\s*$') { for ($i = 1; $i -le $Max; $i++) { $result.Add($i) }; return $result.ToArray() }
    foreach ($part in ($Text -split '[,;\s]+')) {
        if ($part -match '^(\d+)-(\d+)$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            if ($a -gt $b) { $tmp = $a; $a = $b; $b = $tmp }
            for ($i = $a; $i -le $b; $i++) { if ($i -ge 1 -and $i -le $Max -and -not $result.Contains($i)) { $result.Add($i) } }
        } elseif ($part -match '^\d+$') {
            $i = [int]$part
            if ($i -ge 1 -and $i -le $Max -and -not $result.Contains($i)) { $result.Add($i) }
        }
    }
    return $result.ToArray()
}

# ============================================================
# CHANGE ENGINE
# Every change the optimizer makes goes through these functions.
#  - Preview mode: they print what WOULD change and change nothing.
#  - Normal mode : they save the old value to the undo journal
#                  (tweaks_backup.json) and then make the change,
#                  so every tweak can be undone on its own later.
# ============================================================
$Script:GuidPattern  = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$Script:ChangeErrors = 0

function Add-PreviewLine {
    param([string]$Verb, [string]$Text)
    $color = if ($Verb -eq 'no change') { 'DarkGray' } else { 'Cyan' }
    Write-Host ("       [{0}] {1}" -f $Verb, $Text) -ForegroundColor $color
    $Script:PreviewLog.Add(("    [{0}] {1}" -f $Verb, $Text))
}

function Get-RegValue {
    param([string]$Key, [string]$Name)
    try {
        $k = Get-Item -LiteralPath $Key -ErrorAction Stop
        return $k.GetValue($Name, $null)
    } catch { return $null }
}

# ---------------- registry (via .NET, so every value type and the default value work) ----------------
function Split-RegPath {
    param([string]$Path)
    if (-not ($Path -match '^(HKCU|HKLM|HKU|HKCR):\\?(.*)$')) { throw "Unsupported registry path: $Path" }
    $root = $Matches[1]
    $sub  = $Matches[2].TrimEnd('\')
    $hive = switch ($root) {
        'HKCU' { [Microsoft.Win32.RegistryHive]::CurrentUser }
        'HKLM' { [Microsoft.Win32.RegistryHive]::LocalMachine }
        'HKU'  { [Microsoft.Win32.RegistryHive]::Users }
        'HKCR' { [Microsoft.Win32.RegistryHive]::ClassesRoot }
    }
    return @{ Root = $root; Hive = $hive; Sub = $sub; Display = "$root\$sub" }
}

function Open-RegKey {
    param([string]$Path, [switch]$Write, [switch]$Create)
    $p = Split-RegPath $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($p.Hive, [Microsoft.Win32.RegistryView]::Default)
    if ($Create) { return $base.CreateSubKey($p.Sub) }
    return $base.OpenSubKey($p.Sub, [bool]$Write)
}

function Test-RegKey {
    param([string]$Path)
    $k = $null
    try { $k = Open-RegKey $Path } catch {}
    if ($k) { $k.Close(); return $true }
    return $false
}

# DWORDs above 2147483647 (like 0xFFFFFFFF) have to be stored as negative Int32
function ConvertTo-Int32Bits {
    param($Value)
    $n = [int64]$Value
    if ($n -gt [int32]::MaxValue) { $n = $n - 4294967296 }
    return [int32]$n
}

function ConvertTo-RegData {
    param($Value, [string]$Kind)
    switch ($Kind) {
        'DWord'       { return (ConvertTo-Int32Bits $Value) }
        'QWord'       { return [int64]$Value }
        'Binary'      {
            if ($null -eq $Value) { return , ([byte[]]@()) }
            return , ([byte[]]@($Value | ForEach-Object { [byte]$_ }))
        }
        'MultiString' {
            if ($null -eq $Value) { return , ([string[]]@()) }
            return , ([string[]]@($Value))
        }
        default       { return [string]$Value }
    }
}

# Byte arrays are saved as plain numbers in the JSON journal
function ConvertTo-JournalData {
    param($Value, [string]$Kind)
    if ($null -eq $Value) { return $null }
    if ($Kind -eq 'Binary')      { return , ([int[]]@($Value | ForEach-Object { [int]$_ })) }
    if ($Kind -eq 'MultiString') { return , ([string[]]@($Value)) }
    return $Value
}

function Format-RegData {
    param($Value, [string]$Kind)
    switch ($Kind) {
        'DWord' {
            $u = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32](ConvertTo-Int32Bits $Value)), 0)
            return ('{0} (0x{0:X})' -f $u)
        }
        'QWord'       { return [string]$Value }
        'Binary'      { return ((@($Value) | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ' ') }
        'MultiString' { return ('"' + (@($Value) -join '", "') + '"') }
        default       { return ('"' + [string]$Value + '"') }
    }
}

function Test-RegDataEqual {
    param($A, $B, [string]$Kind)
    return ((Format-RegData $A $Kind) -ceq (Format-RegData $B $Kind))
}

function Get-RegState {
    param([string]$Path, [string]$Name)
    $st = @{ KeyExists = $false; Exists = $false; Kind = $null; Value = $null }
    $k = $null
    try { $k = Open-RegKey $Path } catch {}
    if ($k) {
        try {
            $st.KeyExists = $true
            if (@($k.GetValueNames()) -contains $Name) {
                $st.Exists = $true
                $st.Kind   = [string]$k.GetValueKind($Name)
                $st.Value  = $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        } catch {} finally { $k.Close() }
    }
    return $st
}

function Format-RegState {
    param($State)
    if (-not $State.Exists) { return 'not set' }
    return (Format-RegData $State.Value $State.Kind)
}

function Get-RegLabel {
    param([string]$Path, [string]$Name)
    $n = if ($Name) { $Name } else { '(Default)' }
    return ('{0}\{1}' -f (Split-RegPath $Path).Display, $n)
}

# The first key in the path that doesn't exist yet (so Undo can remove what we created)
function Get-MissingKeyRoot {
    param([string]$Path)
    $p = Split-RegPath $Path
    $cur = ''
    foreach ($part in @($p.Sub -split '\\' | Where-Object { $_ })) {
        $cur = if ($cur) { "$cur\$part" } else { $part }
        $test = "$($p.Root):\$cur"
        if (-not (Test-RegKey $test)) { return $test }
    }
    return $null
}

function Write-RegData {
    param([string]$Path, [string]$Name, $Value, [string]$Kind)
    $k = Open-RegKey $Path -Create
    if (-not $k) { throw "Could not open $Path" }
    try { $k.SetValue($Name, (ConvertTo-RegData $Value $Kind), [Microsoft.Win32.RegistryValueKind]$Kind) }
    finally { $k.Close() }
}

function Remove-RegData {
    param([string]$Path, [string]$Name)
    $k = Open-RegKey $Path -Write
    if ($k) { try { $k.DeleteValue($Name, $false) } finally { $k.Close() } }
}

function Test-RegTreeEmpty {
    param($Key)
    if ($Key.ValueCount -gt 0) { return $false }
    foreach ($n in $Key.GetSubKeyNames()) {
        $sk = $Key.OpenSubKey($n)
        if ($sk) {
            $empty = Test-RegTreeEmpty $sk
            $sk.Close()
            if (-not $empty) { return $false }
        }
    }
    return $true
}

# Deletes a key we created, but only if nothing has been put in it since
function Remove-RegTreeIfEmpty {
    param([string]$Path)
    $k = $null
    try { $k = Open-RegKey $Path } catch {}
    if (-not $k) { return }
    $empty = Test-RegTreeEmpty $k
    $k.Close()
    if (-not $empty) { return }
    $p = Split-RegPath $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($p.Hive, [Microsoft.Win32.RegistryView]::Default)
    $base.DeleteSubKeyTree($p.Sub, $false)
}

# Used by every tweak to set a registry value
function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    $label = Get-RegLabel $Path $Name
    $old   = Get-RegState $Path $Name
    $same  = $old.Exists -and $old.Kind -eq $Type -and (Test-RegDataEqual $old.Value $Value $Type)
    if ($Script:Preview) {
        if ($same) { Add-PreviewLine 'no change' "$label is already $(Format-RegData $Value $Type)" }
        else       { Add-PreviewLine 'would set' "$label = $(Format-RegData $Value $Type)   (now: $(Format-RegState $old))" }
        return
    }
    if ($same) { Write-Log "REG unchanged $label"; return }
    try {
        $created = if ($old.KeyExists) { $null } else { Get-MissingKeyRoot $Path }
        Write-RegData $Path $Name $Value $Type
        Save-JournalChange @{ Kind = 'Reg'; Path = $Path; Name = $Name; Existed = $old.Exists; OldKind = $old.Kind
                              OldValue = (ConvertTo-JournalData $old.Value $old.Kind); CreatedKey = $created }
        Write-Log "REG $label = $(Format-RegData $Value $Type) (was: $(Format-RegState $old))"
    } catch {
        Write-Log "REG FAILED $label : $($_.Exception.Message)"
        $Script:ChangeErrors++
    }
}

# Used by tweaks to delete a registry value
function Remove-Reg {
    param([string]$Path, [string]$Name)
    $label = Get-RegLabel $Path $Name
    $old   = Get-RegState $Path $Name
    if (-not $old.Exists) {
        if ($Script:Preview) { Add-PreviewLine 'no change' "$label is not set" }
        return
    }
    if ($Script:Preview) { Add-PreviewLine 'would delete' "$label   (now: $(Format-RegState $old))"; return }
    try {
        Remove-RegData $Path $Name
        Save-JournalChange @{ Kind = 'Reg'; Path = $Path; Name = $Name; Existed = $true; OldKind = $old.Kind
                              OldValue = (ConvertTo-JournalData $old.Value $old.Kind); CreatedKey = $null }
        Write-Log "REG deleted $label (was: $(Format-RegState $old))"
    } catch {
        Write-Log "REG DELETE FAILED $label : $($_.Exception.Message)"
        $Script:ChangeErrors++
    }
}

# ---------------- services ----------------
function Get-ServiceState {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $svc) { return $null }
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
    $start = Get-RegValue $key 'Start'
    if ($null -eq $start) { $start = 3 }
    return @{
        Start   = [int]$start
        Delayed = ([int](Get-RegValue $key 'DelayedAutostart') -eq 1)
        Running = ($svc.Status -eq 'Running')
    }
}

function Format-StartType {
    param($State)
    switch ([int]$State.Start) {
        2       { if ($State.Delayed) { return 'Automatic (delayed)' } else { return 'Automatic' } }
        3       { return 'Manual' }
        4       { return 'Disabled' }
        default { return 'Boot/System' }
    }
}

function Set-ServiceStartup {
    param([string]$Name, [ValidateSet('Disabled', 'Manual', 'Automatic')][string]$Type, [switch]$Stop)
    $st = Get-ServiceState $Name
    if (-not $st) {
        if ($Script:Preview) { Add-PreviewLine 'no change' "service $Name is not installed" }
        return
    }
    $target   = @{ 'Disabled' = 4; 'Manual' = 3; 'Automatic' = 2 }[$Type]
    $willStop = $Stop -and $st.Running
    $same     = ($st.Start -eq $target) -and -not $willStop
    $now      = Format-StartType $st
    if ($st.Running) { $now += ', running' }
    if ($Script:Preview) {
        if ($same) { Add-PreviewLine 'no change' "service $Name is already $Type" }
        else {
            $extra = if ($willStop) { ' and stop it now' } else { '' }
            Add-PreviewLine 'would set' "service $Name startup = $Type$extra   (now: $now)"
        }
        return
    }
    if ($same) { return }
    Save-JournalChange @{ Kind = 'Service'; Name = $Name; OldStart = $st.Start; OldDelayed = $st.Delayed; WasRunning = $st.Running }
    if ($willStop) { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
    if ($st.Start -ne $target) {
        try { Set-Service -Name $Name -StartupType $Type -ErrorAction Stop }
        catch {
            try { Write-RegData "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" 'Start' $target 'DWord' }
            catch { $Script:ChangeErrors++; Write-Log "SERVICE FAILED $Name : $($_.Exception.Message)"; return }
        }
    }
    Write-Log "SERVICE $Name -> $Type (was: $now)"
}

function Restore-ServiceState {
    param($Change)
    $name  = [string]$Change.Name
    $start = [int]$Change.OldStart
    $key   = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
    $type  = switch ($start) { 2 { 'Automatic' } 3 { 'Manual' } 4 { 'Disabled' } default { $null } }
    $ok = $false
    if ($type) { try { Set-Service -Name $name -StartupType $type -ErrorAction Stop; $ok = $true } catch {} }
    if (-not $ok) { Write-RegData $key 'Start' $start 'DWord' }
    if ($start -eq 2 -and $Change.OldDelayed) { Write-RegData $key 'DelayedAutostart' 1 'DWord' }
    if ($Change.WasRunning) { Start-Service -Name $name -ErrorAction SilentlyContinue }
}

# ---------------- scheduled tasks ----------------
function Disable-TaskSafe {
    param([string]$TaskPath, [string]$TaskName)
    if (-not $Script:Has.Tasks) { return }
    $t = $null
    try { $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop } catch {}
    if (-not $t) {
        if ($Script:Preview) { Add-PreviewLine 'no change' "scheduled task $TaskPath$TaskName doesn't exist here" }
        return
    }
    if ($t.State -eq 'Disabled') {
        if ($Script:Preview) { Add-PreviewLine 'no change' "scheduled task $TaskPath$TaskName is already disabled" }
        return
    }
    if ($Script:Preview) { Add-PreviewLine 'would disable' "scheduled task $TaskPath$TaskName   (now: $($t.State))"; return }
    try {
        $t | Disable-ScheduledTask -ErrorAction Stop | Out-Null
        Save-JournalChange @{ Kind = 'Task'; TaskPath = $TaskPath; TaskName = $TaskName }
        Write-Log "TASK disabled $TaskPath$TaskName"
    } catch {
        Write-Log "TASK FAILED $TaskPath$TaskName : $($_.Exception.Message)"
        $Script:ChangeErrors++
    }
}

# ---------------- power ----------------
function Get-ActivePowerScheme {
    $out = (powercfg /getactivescheme 2>$null) -join ' '
    if ($out -match "($Script:GuidPattern)\s*\(([^)]*)\)") { return @{ Guid = $Matches[1]; Name = $Matches[2] } }
    if ($out -match "($Script:GuidPattern)") { return @{ Guid = $Matches[1]; Name = $Matches[1] } }
    return $null
}

function Set-PowerScheme {
    param([string]$Guid, [string]$Label)
    $current = Get-ActivePowerScheme
    if ($Script:Preview) {
        $nowName = if ($current) { $current.Name } else { 'unknown' }
        Add-PreviewLine 'would set' "power plan = $Label   (now: $nowName)"
        return $true
    }
    $list = (powercfg /list) -join "`n"
    $target = $null
    if ($list -match [regex]::Escape($Guid)) {
        $target = $Guid
    } else {
        foreach ($line in ($list -split "`n")) {
            if ($line -match [regex]::Escape($Label) -and $line -match "($Script:GuidPattern)") { $target = $Matches[1]; break }
        }
        if (-not $target) {
            $out = (powercfg /duplicatescheme $Guid 2>&1) -join ' '
            if ($out -match "($Script:GuidPattern)") { $target = $Matches[1] }
        }
    }
    if (-not $target) { return $false }
    if ($current -and $current.Guid -eq $target) { return $true }
    powercfg /setactive $target | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($current) { Save-JournalChange @{ Kind = 'Power'; OldScheme = $current.Guid; OldName = $current.Name } }
    Write-Log "POWER plan -> $Label (was: $(if ($current) { $current.Name }))"
    return $true
}

# Reads the "plugged in" value of a power setting, in seconds
function Get-PowerValueAC {
    param([string]$Scheme, [string]$Sub, [string]$Setting)
    $hex = @()
    foreach ($l in @(powercfg /query $Scheme $Sub $Setting 2>$null)) {
        if ($l -match '0x([0-9a-fA-F]+)\s*$') { $hex += $Matches[1] }
    }
    # Last two values are "Current AC" and "Current DC"
    if ($hex.Count -ge 2) { return [Convert]::ToInt64($hex[-2], 16) }
    return $null
}

function Format-Timeout {
    param($Seconds)
    if ($null -eq $Seconds) { return 'unknown' }
    if ([int64]$Seconds -eq 0) { return 'never' }
    return ('{0} min' -f [math]::Round([int64]$Seconds / 60))
}

# Sets how long until sleep/hibernate when plugged in (0 = never)
function Set-PowerTimeoutAC {
    param([ValidateSet('STANDBYIDLE', 'HIBERNATEIDLE')][string]$Setting, [string]$Label, [int]$Seconds)
    $scheme = Get-ActivePowerScheme
    if (-not $scheme) { return }
    $old = Get-PowerValueAC $scheme.Guid 'SUB_SLEEP' $Setting
    $same = ($null -ne $old) -and ([int64]$old -eq $Seconds)
    if ($Script:Preview) {
        if ($same) { Add-PreviewLine 'no change' "$Label (plugged in) is already $(Format-Timeout $Seconds)" }
        else       { Add-PreviewLine 'would set' "$Label (plugged in) = $(Format-Timeout $Seconds)   (now: $(Format-Timeout $old))" }
        return
    }
    if ($same) { return }
    powercfg /setacvalueindex $scheme.Guid SUB_SLEEP $Setting $Seconds | Out-Null
    powercfg /setactive $scheme.Guid | Out-Null
    if ($null -ne $old) { Save-JournalChange @{ Kind = 'PowerValue'; Scheme = $scheme.Guid; Sub = 'SUB_SLEEP'; Setting = $Setting; OldAC = $old } }
    Write-Log "POWER $Setting AC = $Seconds (was: $old)"
}

function Get-HibernateOn {
    $v = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
    if ($null -ne $v) { return ([int]$v -eq 1) }
    return [bool](Get-Item -LiteralPath "$env:SystemDrive\hiberfil.sys" -Force -ErrorAction SilentlyContinue)
}

function Set-Hibernation {
    param([bool]$On)
    $was = Get-HibernateOn
    $word = if ($On) { 'on' } else { 'off' }
    if ($Script:Preview) {
        if ($was -eq $On) { Add-PreviewLine 'no change' "hibernation is already $word" }
        else { Add-PreviewLine 'would run' "powercfg /h $word   (hibernation is now $(if ($was) { 'on' } else { 'off' }))" }
        return
    }
    if ($was -eq $On) { return }
    powercfg /h $word | Out-Null
    Save-JournalChange @{ Kind = 'Hibernate'; WasOn = $was }
    Write-Log "POWER hibernation $word"
}

# ---------------- things that can't be undone automatically ----------------
function Invoke-Step {
    param([string]$Description, [scriptblock]$Block)
    if ($Script:Preview) { Add-PreviewLine 'would run' $Description; return }
    & $Block
    Save-JournalChange @{ Kind = 'Note'; Text = $Description }
    Write-Log "STEP $Description"
}

function Restart-Explorer {
    $Script:NeedsExplorerRestart = $false
    if ($Script:Preview -or $Script:NonInteractive) { return }
    Pink "`n  Restarting Explorer to apply visual changes..."
    Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)) { Start-Process 'explorer.exe' }
}

# ============================================================
# UNDO JOURNAL
# One record per tweak: { Title, Date, Explorer, Changes[] }
# ============================================================
function Get-TweakJournal {
    if (-not (Test-Path -LiteralPath $Script:JournalFile)) { return @() }
    try {
        $data = Get-Content -LiteralPath $Script:JournalFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return @($data)
    } catch { return @() }
}

function Save-TweakJournal {
    param($Records)
    $arr = @($Records | Where-Object { $_ })
    if ($arr.Count -eq 0) { Remove-Item -LiteralPath $Script:JournalFile -Force -ErrorAction SilentlyContinue; return }
    ConvertTo-Json -InputObject $arr -Depth 8 | Set-Content -LiteralPath $Script:JournalFile -Encoding UTF8
}

function Start-TweakRecord {
    param([string]$Title, [bool]$Explorer)
    $Script:CurrentRecord = $null
    if ($Script:Preview) { return }
    $existing = @(Get-TweakJournal | Where-Object { $_.Title -eq $Title }) | Select-Object -First 1
    $changes = @()
    if ($existing) { $changes = @($existing.Changes | Where-Object { $_ }) }
    $Script:CurrentRecord = [pscustomobject]@{
        Title = $Title; Date = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Explorer = $Explorer; Changes = $changes
    }
}

function Get-ChangeId {
    param($Change)
    switch ($Change.Kind) {
        'Reg'        { return ("Reg|{0}|{1}" -f $Change.Path, $Change.Name).ToLower() }
        'Service'    { return ("Service|{0}" -f $Change.Name).ToLower() }
        'Task'       { return ("Task|{0}{1}" -f $Change.TaskPath, $Change.TaskName).ToLower() }
        'Power'      { return 'Power|scheme' }
        'PowerValue' { return ("PowerValue|{0}|{1}" -f $Change.Scheme, $Change.Setting).ToLower() }
        'Hibernate'  { return 'Hibernate' }
        default      { return ("Note|{0}" -f $Change.Text) }
    }
}

function Save-JournalChange {
    param([hashtable]$Change)
    if (-not $Script:CurrentRecord) { return }
    $id = Get-ChangeId $Change
    # If this tweak was applied before, keep the ORIGINAL value from the first time
    if (@($Script:CurrentRecord.Changes | Where-Object { $_.Id -eq $id }).Count -gt 0) { return }
    $Change.Id = $id
    $Script:CurrentRecord.Changes = @($Script:CurrentRecord.Changes) + @([pscustomobject]$Change)
    # Saved straight away, so even if something crashes halfway the change can still be undone
    $others = @(Get-TweakJournal | Where-Object { $_.Title -ne $Script:CurrentRecord.Title })
    Save-TweakJournal (@($others) + @($Script:CurrentRecord))
}

function Get-ChangeDescription {
    param($Change)
    switch ($Change.Kind) {
        'Reg' {
            $label = Get-RegLabel $Change.Path $Change.Name
            if ($Change.Existed) { return "restore $label = $(Format-RegData (ConvertTo-RegData $Change.OldValue $Change.OldKind) $Change.OldKind)" }
            return "delete $label (it didn't exist before)"
        }
        'Service' {
            $st = @{ Start = [int]$Change.OldStart; Delayed = [bool]$Change.OldDelayed }
            $extra = if ($Change.WasRunning) { ' and start it' } else { '' }
            return "set service $($Change.Name) back to $(Format-StartType $st)$extra"
        }
        'Task'       { return "re-enable scheduled task $($Change.TaskPath)$($Change.TaskName)" }
        'Power'      { return "switch the power plan back to $($Change.OldName)" }
        'PowerValue' { return "set $($Change.Setting) (plugged in) back to $(Format-Timeout $Change.OldAC)" }
        'Hibernate'  { return "turn hibernation back $(if ($Change.WasOn) { 'on' } else { 'off' })" }
        default      { return [string]$Change.Text }
    }
}

function Undo-Change {
    param($Change)
    switch ($Change.Kind) {
        'Reg' {
            if ($Change.Existed) {
                Write-RegData $Change.Path $Change.Name (ConvertTo-RegData $Change.OldValue $Change.OldKind) $Change.OldKind
            } else {
                Remove-RegData $Change.Path $Change.Name
                if ($Change.CreatedKey) { Remove-RegTreeIfEmpty $Change.CreatedKey }
            }
        }
        'Service'    { Restore-ServiceState $Change }
        'Task'       { Enable-ScheduledTask -TaskPath $Change.TaskPath -TaskName $Change.TaskName -ErrorAction Stop | Out-Null }
        'Power'      { powercfg /setactive $Change.OldScheme | Out-Null }
        'PowerValue' {
            powercfg /setacvalueindex $Change.Scheme $Change.Sub $Change.Setting $Change.OldAC | Out-Null
            $cur = Get-ActivePowerScheme
            if ($cur) { powercfg /setactive $cur.Guid | Out-Null }
        }
        'Hibernate'  { powercfg /h $(if ($Change.WasOn) { 'on' } else { 'off' }) | Out-Null }
    }
}

# Undoes one tweak (all its changes, newest first). Returns how many changes failed.
function Undo-TweakRecord {
    param($Record)
    $changes = @($Record.Changes | Where-Object { $_ })
    [array]::Reverse($changes)
    $fails = 0
    $notes = @()
    foreach ($c in $changes) {
        if ($c.Kind -eq 'Note') { $notes += [string]$c.Text; continue }
        $desc = Get-ChangeDescription $c
        if ($Script:Preview) { Add-PreviewLine 'would' $desc; continue }
        try { Undo-Change $c; Write-Log "UNDO $desc" }
        catch {
            $fails++
            Write-Log "UNDO FAILED $desc : $($_.Exception.Message)"
            Warn "Couldn't $desc ($($_.Exception.Message))"
        }
    }
    foreach ($n in $notes) { Info "Can't be undone automatically: $n" }
    if (-not $Script:Preview) {
        Save-TweakJournal @(Get-TweakJournal | Where-Object { $_.Title -ne $Record.Title })
        if ($Record.Explorer) { $Script:NeedsExplorerRestart = $true }
    }
    return $fails
}

# Used by the self-test: is this change back to how it was?
function Test-ChangeRestored {
    param($Change)
    switch ($Change.Kind) {
        'Reg' {
            $now = Get-RegState $Change.Path $Change.Name
            if ($Change.Existed) {
                return ($now.Exists -and $now.Kind -eq $Change.OldKind -and
                        (Test-RegDataEqual $now.Value (ConvertTo-RegData $Change.OldValue $Change.OldKind) $Change.OldKind))
            }
            return (-not $now.Exists)
        }
        'Service' {
            $now = Get-ServiceState $Change.Name
            return ($null -ne $now -and $now.Start -eq [int]$Change.OldStart)
        }
        'Task' {
            $t = $null
            try { $t = Get-ScheduledTask -TaskPath $Change.TaskPath -TaskName $Change.TaskName -ErrorAction Stop } catch {}
            return ($null -ne $t -and $t.State -ne 'Disabled')
        }
        'Power'      { $cur = Get-ActivePowerScheme; return ($null -ne $cur -and $cur.Guid -eq $Change.OldScheme) }
        'PowerValue' { return ((Get-PowerValueAC $Change.Scheme $Change.Sub $Change.Setting) -eq [int64]$Change.OldAC) }
        'Hibernate'  { return ((Get-HibernateOn) -eq [bool]$Change.WasOn) }
        default      { return $true }
    }
}

# ------------------------------------------------------------
# File helpers
# ------------------------------------------------------------
function Test-FileExists {
    param([string]$Path)
    if (-not $Path) { return $false }
    try { return [System.IO.File]::Exists($Path) } catch { return $false }
}

function Get-FileInfo {
    param([string]$Path)
    $r = @{ Company = ''; Description = '' }
    if (Test-FileExists $Path) {
        try {
            $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            if ($vi.CompanyName)     { $r.Company     = $vi.CompanyName.Trim() }
            if ($vi.FileDescription) { $r.Description = $vi.FileDescription.Trim() }
        } catch {}
    }
    return $r
}

# Works out which program a startup command actually runs
function Get-ExeFromCommand {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return '' }
    $c = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    $path = ''
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -gt 1) { $path = $c.Substring(1, $end - 1) } else { $path = $c.Trim('"') }
    } elseif ($c -match '^(.+?\.(exe|com|bat|cmd|vbs|js|ps1|lnk|dll))(?=\s|,|$)') {
        $path = $Matches[1]
    } else {
        $path = ($c -split '\s+')[0]
    }

    # For things like rundll32 / wscript / cmd, find the real target in the arguments
    $leaf = ($path -split '[\\/]')[-1]
    if ($leaf -match '^(rundll32|wscript|cscript|cmd|powershell|pwsh|conhost|mshta|regsvr32|javaw?)(\.exe)?$') {
        $idx  = $c.IndexOf($leaf, [StringComparison]::OrdinalIgnoreCase)
        $rest = if ($idx -ge 0) { $c.Substring([Math]::Min($c.Length, $idx + $leaf.Length)) } else { $c }
        $m = [regex]::Matches($rest, '[A-Za-z]:\\[^"<>|*?\r\n]+?\.(exe|dll|vbs|js|ps1|bat|cmd|jar)')
        if ($m.Count -gt 0) { $path = $m[0].Value }
    }

    if ($path -and $path -notmatch '^[A-Za-z]:\\|^\\\\') {
        $cmd = Get-Command $path -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $path = $cmd.Source }
    }
    return $path
}

function Get-FolderSize {
    param([string[]]$Paths)
    $total = 0
    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            $sum = (Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($sum) { $total += $sum }
        }
    }
    return [double]$total
}

function Clear-Folder {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ------------------------------------------------------------
# Compatibility helpers
# ------------------------------------------------------------
# Which optional Windows tools exist on this PC (some are missing on
# Windows 8.1, Server, LTSC and stripped-down Windows builds)
$Script:Has = @{
    Tasks       = [bool](Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)
    Appx        = [bool](Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)
    Provisioned = [bool](Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)
    Storage     = [bool](Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue)
    RecycleBin  = [bool](Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue)
}

# WMI query that never crashes: tries CIM, then old-style WMI, else returns nothing
function Get-CimSafe {
    param([string]$Class, [string]$Filter = '', [string]$Namespace = 'root/cimv2')
    try {
        if ($Filter) { return Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter -ErrorAction Stop }
        return Get-CimInstance -Namespace $Namespace -ClassName $Class -ErrorAction Stop
    } catch {
        try {
            if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
                $ns = $Namespace -replace '/', '\'
                if ($Filter) { return Get-WmiObject -Namespace $ns -Class $Class -Filter $Filter -ErrorAction Stop }
                return Get-WmiObject -Namespace $ns -Class $Class -ErrorAction Stop
            }
        } catch {}
    }
    return $null
}

function Get-InstalledAppx {
    if (-not $Script:Has.Appx) { return @() }
    $list = @()
    try { $list = @(Get-AppxPackage -AllUsers -ErrorAction Stop) } catch {}
    if ($list.Count -eq 0) { try { $list = @(Get-AppxPackage -ErrorAction Stop) } catch {} }
    return $list
}

function Get-AllTasks {
    if (-not $Script:Has.Tasks) { return @() }
    try { return @(Get-ScheduledTask -ErrorAction Stop) } catch { return @() }
}

# ============================================================
# PC SCAN
# ============================================================
function Get-SystemProfile {
    Write-Host "  Scanning your PC, this takes a few seconds..." -ForegroundColor Gray
    $s = @{}

    $cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $os = Get-CimSafe 'Win32_OperatingSystem' | Select-Object -First 1

    # Windows name/build (registry fallback if WMI is broken)
    $s.Build = 0
    if ($os -and $os.BuildNumber) { $s.Build = [int]$os.BuildNumber }
    if (-not $s.Build) { $s.Build = [int](Get-RegValue $cv 'CurrentBuildNumber') }
    if (-not $s.Build) { $s.Build = [Environment]::OSVersion.Version.Build }
    $s.IsWin11 = $s.Build -ge 22000
    $s.OSName = if ($os -and $os.Caption) { ([string]$os.Caption).Trim() } else { [string](Get-RegValue $cv 'ProductName') }
    if ($s.IsWin11) { $s.OSName = $s.OSName -replace 'Windows 10', 'Windows 11' }   # registry still says "10" on Win11
    if (-not $s.OSName) { $s.OSName = 'Windows' }
    $s.Edition   = [string](Get-RegValue $cv 'EditionID')
    $s.IsHome    = $s.Edition -match '^Core'          # Home editions are "Core..."
    $s.IsServer  = ($s.OSName -match 'Server') -or ($os -and $os.ProductType -gt 1)
    $s.Arch      = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $s.Arch = $env:PROCESSOR_ARCHITEW6432 }

    # RAM
    $s.RamGB = 0; $s.FreeRamGB = 0
    if ($os -and $os.TotalVisibleMemorySize) {
        $s.RamGB     = [math]::Round([double]$os.TotalVisibleMemorySize / 1MB, 1)
        $s.FreeRamGB = [math]::Round([double]$os.FreePhysicalMemory / 1MB, 1)
    }

    # Uptime (CIM gives a date, old WMI gives a string)
    $s.UptimeDays = 0; $s.UptimeText = 'Unknown'
    try {
        $boot = $os.LastBootUpTime
        if ($boot -is [string]) { $boot = [Management.ManagementDateTimeConverter]::ToDateTime($boot) }
        if ($boot -is [datetime]) {
            $up = (Get-Date) - $boot
            $s.UptimeDays = [int][math]::Floor($up.TotalDays)
            $s.UptimeText = "{0} day(s), {1} hour(s)" -f $s.UptimeDays, $up.Hours
        }
    } catch {}

    # Laptop or desktop
    $cs = Get-CimSafe 'Win32_ComputerSystem' | Select-Object -First 1
    $chassis = @(Get-CimSafe 'Win32_SystemEnclosure' | ForEach-Object { $_.ChassisTypes })
    $portable = [bool]($chassis | Where-Object { @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) -contains $_ })
    $hasBattery = [bool](Get-CimSafe 'Win32_Battery')
    $s.IsLaptop = $portable -or ($cs -and $cs.PCSystemType -eq 2) -or ($hasBattery -and -not $chassis.Count)

    # Who is signed in vs. who is running this (matters for per-user settings)
    $s.RunningAs   = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $s.ConsoleUser = if ($cs -and $cs.UserName) { [string]$cs.UserName } else { '' }

    $cpu = Get-CimSafe 'Win32_Processor' | Select-Object -First 1
    $s.CPU = if ($cpu -and $cpu.Name) { ([string]$cpu.Name).Trim() } else { [string](Get-RegValue 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' 'ProcessorNameString') }
    if (-not $s.CPU) { $s.CPU = 'Unknown' }
    $s.GPUs = @(Get-CimSafe 'Win32_VideoController' | ForEach-Object { $_.Name } | Where-Object { $_ })
    $s.HasNvidia    = [bool]($s.GPUs -match 'NVIDIA')
    $s.HasAMDGpu    = [bool]($s.GPUs -match 'AMD|Radeon')
    $s.HasDedicated = [bool]($s.GPUs -match 'NVIDIA|Radeon RX|Radeon Pro|Arc')

    # System drive
    $s.DiskType = 'Unknown'
    if ($Script:Has.Storage) { try {
        $part = Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1) -ErrorAction Stop
        $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { [string]$_.DeviceId -eq [string]$part.DiskNumber } | Select-Object -First 1
        if ($pd) {
            $s.DiskType = [string]$pd.MediaType
            if ([string]$pd.BusType -eq 'NVMe') { $s.DiskType = 'NVMe SSD' }
        }
    } catch {} }
    $s.IsSSD = $s.DiskType -match 'SSD|NVMe'
    $s.IsHDD = $s.DiskType -eq 'HDD'
    $ld = Get-CimSafe 'Win32_LogicalDisk' "DeviceID='$($env:SystemDrive)'" | Select-Object -First 1
    if (-not $ld) { try { $ld = [System.IO.DriveInfo]::new($env:SystemDrive) | Select-Object @{ n = 'Size'; e = { $_.TotalSize } }, @{ n = 'FreeSpace'; e = { $_.AvailableFreeSpace } } } catch {} }
    if ($ld -and $ld.Size) {
        $s.DiskFreeGB = [math]::Round($ld.FreeSpace / 1GB, 1)
        $s.DiskSizeGB = [math]::Round($ld.Size / 1GB, 0)
        $s.DiskFreePct = [math]::Round(100 * $ld.FreeSpace / $ld.Size, 0)
    } else { $s.DiskFreeGB = 0; $s.DiskSizeGB = 0; $s.DiskFreePct = 100 }

    # Installed programs
    $s.Programs = @(Get-ItemProperty -Path $Script:UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } | ForEach-Object { [string]$_.DisplayName } | Sort-Object -Unique)

    $launchers = [ordered]@{
        'Steam'           = '^Steam$'
        'Epic Games'      = 'Epic Games Launcher'
        'Battle.net'      = 'Battle\.net'
        'EA app'          = '^EA app$|^Origin$'
        'Ubisoft Connect' = 'Ubisoft Connect|Uplay'
        'Riot Games'      = 'Riot Client|VALORANT|League of Legends'
        'GOG Galaxy'      = 'GOG GALAXY'
    }
    $s.GameLaunchers = @()
    foreach ($k in $launchers.Keys) { if ($s.Programs -match $launchers[$k]) { $s.GameLaunchers += $k } }

    $s.HasOneDrive = (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") -or
                     (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe") -or
                     (Test-Path "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") -or
                     [bool](Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue)
    $s.HasEdge = (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") -or
                 (Test-Path "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")

    $s.Appx = @(Get-InstalledAppx)
    $s.HasXbox = [bool]($s.Appx | Where-Object { $_.Name -like 'Microsoft.Xbox*' -or $_.Name -eq 'Microsoft.GamingApp' })
    $s.Health = @()

    return $s
}

# ============================================================
# HEALTH CHECKS (shown in the PC report)
# Each result: Status = OK / WARN / INFO, Text = what to tell the user
# ============================================================
function Get-HealthChecks {
    $results = New-Object System.Collections.Generic.List[object]
    $add = { param($Status, $Text) $results.Add([pscustomobject]@{ Status = $Status; Text = $Text }) }

    # ---- Disk health (SMART) ----
    try {
        $disksChecked = 0
        if ($Script:Has.Storage) {
            foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
                $disksChecked++
                $name = ([string]$pd.FriendlyName).Trim()
                $health = [string]$pd.HealthStatus
                $details = @()
                $worn = $false; $hot = $false
                try {
                    $rc = $pd | Get-StorageReliabilityCounter -ErrorAction Stop
                    if ($null -ne $rc.Wear -and [int]$rc.Wear -gt 0) {
                        $details += "$($rc.Wear)% worn"
                        if ([int]$rc.Wear -ge 90) { $worn = $true }
                    }
                    if ($rc.Temperature -and [int]$rc.Temperature -gt 0) {
                        $details += "$($rc.Temperature) C"
                        if ([int]$rc.Temperature -ge 70) { $hot = $true }
                    }
                } catch {}
                $detailText = if ($details.Count) { " ($($details -join ', '))" } else { '' }
                if ($health -eq 'Healthy' -and -not $worn -and -not $hot) {
                    & $add 'OK' "Disk '$name': healthy$detailText"
                } elseif ($health -eq 'Healthy') {
                    $why = if ($worn) { 'almost worn out - back up your files and plan a replacement' } else { 'running hot - check airflow' }
                    & $add 'WARN' "Disk '$name': $why$detailText"
                } else {
                    & $add 'WARN' "Disk '$name': Windows reports it as '$health'$detailText - BACK UP YOUR FILES NOW, the drive may be failing"
                }
            }
        }
        if ($disksChecked -eq 0) {
            # Fallback: classic SMART failure prediction
            foreach ($d in @(Get-CimSafe 'MSStorageDriver_FailurePredictStatus' -Namespace 'root/wmi')) {
                $disksChecked++
                if ($d.PredictFailure) { & $add 'WARN' "A disk reports a SMART failure warning - BACK UP YOUR FILES NOW" }
                else { & $add 'OK' 'Disk SMART status: no failure predicted' }
            }
        }
        if ($disksChecked -eq 0) { & $add 'INFO' "Disk health: Windows doesn't report it on this PC" }
    } catch { Write-Log "HEALTH disk check failed: $($_.Exception.Message)" }

    # ---- GPU driver ----
    try {
        foreach ($g in @(Get-CimSafe 'Win32_VideoController')) {
            $name = ([string]$g.Name).Trim()
            if (-not $name -or $name -match 'Remote Display|Hyper-V|Parsec|Virtual Display|Meta Virtual|Citrix|VMware SVGA|VirtualBox') { continue }
            if ($name -match 'Microsoft Basic (Display|Render)') {
                & $add 'WARN' "Graphics: no proper driver installed (using 'Microsoft Basic Display Adapter') - install your NVIDIA/AMD/Intel driver"
                continue
            }
            $date = $g.DriverDate
            if ($date -is [string]) { try { $date = [Management.ManagementDateTimeConverter]::ToDateTime($date) } catch { $date = $null } }
            if ($date -isnot [datetime]) { & $add 'INFO' "GPU '$name': driver $($g.DriverVersion)"; continue }
            $months = [int][math]::Floor(((Get-Date) - $date).TotalDays / 30.4)
            $where = if ($name -match 'NVIDIA') { 'the NVIDIA app or nvidia.com' }
                     elseif ($name -match 'AMD|Radeon') { 'AMD Software: Adrenalin Edition or amd.com' }
                     elseif ($name -match 'Intel') { 'the Intel Driver & Support Assistant (or your laptop maker)' }
                     else { "the maker's website" }
            $text = "GPU '$name': driver from $($date.ToString('yyyy-MM-dd')) ($months month(s) old)"
            if ($months -ge 12)    { & $add 'WARN' "$text - update it from $where" }
            elseif ($months -ge 6) { & $add 'INFO' "$text - a newer one is probably available from $where" }
            else                   { & $add 'OK'   $text }
        }
    } catch { Write-Log "HEALTH gpu check failed: $($_.Exception.Message)" }

    # ---- RAM speed (XMP / EXPO) ----
    try {
        $sticks = @(Get-CimSafe 'Win32_PhysicalMemory' | Where-Object { $_.Speed })
        if ($sticks.Count) {
            $rated   = [int](($sticks | Measure-Object -Property Speed -Minimum).Minimum)
            $current = [int](($sticks | Where-Object { $_.ConfiguredClockSpeed } | Measure-Object -Property ConfiguredClockSpeed -Minimum).Minimum)
            if ($current -gt 0 -and $current * 2 -eq $rated) { $current = $rated }   # some PCs report MHz instead of MT/s
            $isDesktop = -not $Script:Sys.IsLaptop
            if ($current -gt 0 -and $current -lt $rated) {
                if ($isDesktop) { & $add 'WARN' "RAM runs at $current MT/s but is rated for $rated MT/s - turn on XMP (Intel) / EXPO (AMD) in your BIOS for free performance" }
                else            { & $add 'INFO' "RAM runs at $current MT/s (rated $rated MT/s) - laptops usually can't change this" }
            } elseif ($current -gt 0) {
                # Windows can only see the standard (JEDEC) speed, so a kit sold as faster can still have XMP/EXPO off
                $jedec = @(1600, 1866, 2133, 2400, 2666, 2933, 3200, 4800, 5200, 5600)
                if ($isDesktop -and $jedec -contains $current) {
                    & $add 'INFO' "RAM runs at $current MT/s (a standard speed). If your RAM kit is sold as faster (check its box/label), turn on XMP/EXPO in the BIOS"
                } else {
                    & $add 'OK' "RAM runs at $current MT/s"
                }
            }
        }
    } catch { Write-Log "HEALTH ram check failed: $($_.Exception.Message)" }

    return $results
}

function Get-HiberInfo {
    $hf = Get-Item -LiteralPath "$env:SystemDrive\hiberfil.sys" -Force -ErrorAction SilentlyContinue
    if ($hf) { return @{ On = $true; GB = [math]::Round($hf.Length / 1GB, 1) } }
    # Fallback if the file can't be read: check the registry switch
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 1) {
        return @{ On = $true; GB = [math]::Round($Script:Sys.RamGB * 0.4, 1) }
    }
    return @{ On = $false; GB = 0 }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Pink  "  =================================================="
    Pink  '   _'
    Pink  '  | |      ___  _ __ __  __ _ __    __ _'
    Pink  '  | |     / _ \| ''__|\ \/ /| ''_ \  / _` |'
    Pink  '  | |___ |  __/| |    >  < | | | || (_| |'
    Pink  '  |_____| \___||_|   /_/\_\|_| |_| \__,_|'
    Pink  ""
    Pink  "        O p t i m i z e r  v$($Script:Version)"
    Pink  "  =================================================="
    if ($Script:Preview) {
        Write-Host "   PREVIEW MODE - shows what would change, changes nothing" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Show-SystemReport {
    $s = $Script:Sys
    Section "Your PC"
    $gpuText = if ($s.GPUs.Count) { $s.GPUs -join ' + ' } else { 'Unknown' }
    $kind    = if ($s.IsLaptop) { 'Laptop' } else { 'Desktop' }
    Write-Host ("   Windows  : {0} (build {1}, {2})" -f $s.OSName, $s.Build, $s.Arch)
    Write-Host ("   Type     : {0}" -f $kind)
    Write-Host ("   CPU      : {0}" -f $s.CPU)
    Write-Host ("   GPU      : {0}" -f $gpuText)
    Write-Host ("   RAM      : {0} GB ({1} GB free right now)" -f $s.RamGB, $s.FreeRamGB)
    Write-Host ("   Disk     : {0} {1} - {2} GB free of {3} GB ({4}%)" -f $env:SystemDrive, $s.DiskType, $s.DiskFreeGB, $s.DiskSizeGB, $s.DiskFreePct)
    Write-Host ("   Uptime   : {0}" -f $s.UptimeText)
    if ($s.GameLaunchers.Count) { Write-Host ("   Gaming   : {0}" -f ($s.GameLaunchers -join ', ')) }

    # Health checks
    if (-not $s.Health -or @($s.Health).Count -eq 0) { $s.Health = @(Get-HealthChecks) }
    if (@($s.Health).Count) {
        Write-Host ""
        Write-Host "   Health:" -ForegroundColor White
        foreach ($h in $s.Health) {
            $tag   = switch ($h.Status) { 'OK' { '[OK]' } 'WARN' { '[!!]' } default { '[i] ' } }
            $color = switch ($h.Status) { 'OK' { 'Green' } 'WARN' { 'Yellow' } default { 'Gray' } }
            Write-Host "    $tag " -ForegroundColor $color -NoNewline
            Write-Host $h.Text
            Write-Log "HEALTH $($h.Status): $($h.Text)"
        }
    }

    $on   = @($Script:LastScan | Where-Object { $_.Enabled })
    $safe = @($on | Where-Object { $_.Rec -eq 'Disable' })
    $run  = @($on | Where-Object { $_.Running })
    $runMB = ($run | Measure-Object -Property MemMB -Sum).Sum
    if (-not $runMB) { $runMB = 0 }
    Write-Host ("   Startup  : {0} things start with Windows ({1} running now using ~{2} MB, {3} safe to turn off)" -f $on.Count, $run.Count, $runMB, $safe.Count)

    # Tips based on the scan
    $tips = @()
    if ($s.UptimeDays -ge 7)            { $tips += "Your PC hasn't fully restarted in $($s.UptimeDays) days - a restart alone often fixes slowdowns." }
    if ($s.RamGB -lt 8)                 { $tips += "You have $($s.RamGB) GB of RAM - turning off startup apps will make a big difference." }
    if ($s.IsHDD)                       { $tips += "Windows is on a hard drive (HDD). Moving to an SSD is the single biggest speed upgrade you can make." }
    if ($s.DiskFreePct -lt 15)          { $tips += "Your $($env:SystemDrive) drive is only $($s.DiskFreePct)% free - run 'Clean junk files' from the menu." }
    if ($safe.Count -ge 3)              { $tips += "$($safe.Count) startup items are safe to turn off - try the Startup scanner (option 3)." }
    if ($s.IsLaptop)                    { $tips += "Laptop detected - tweaks that drain battery won't be marked as recommended." }
    if ($s.GameLaunchers.Count)         { $tips += "Games detected - don't miss the Gaming tweaks." }
    if ($s.IsHome)                      { $tips += "Windows Home edition: a few privacy settings are 'policies' that Home only partly follows. They're still safe to apply." }
    if ($s.IsServer)                    { $tips += "Windows Server detected - only apply tweaks you understand; some (Xbox, Store apps) don't exist here." }
    if (-not $Script:Has.Appx)          { $tips += "This Windows has no Store app support, so app removal is hidden." }
    if ($s.ConsoleUser -and $s.RunningAs -and ($s.ConsoleUser -ne $s.RunningAs)) {
        $tips += "You're signed in as $($s.ConsoleUser) but running this as $($s.RunningAs). Per-user settings (dark mode, taskbar, your startup apps) will apply to $($s.RunningAs)."
    }
    if ($tips.Count) {
        Write-Host ""
        Write-Host "   Tips for your PC:" -ForegroundColor Cyan
        foreach ($t in $tips) { Write-Host "    * $t" -ForegroundColor Cyan }
    }

    Write-Log ("PC: {0} build {1} | {2} | CPU {3} | GPU {4} | RAM {5}GB | Disk {6} {7}GB free" -f $s.OSName, $s.Build, $kind, $s.CPU, $gpuText, $s.RamGB, $s.DiskType, $s.DiskFreeGB)
}

# ============================================================
# RESTORE POINT
# ============================================================
function New-RestorePoint {
    if ($Script:Preview) { Add-PreviewLine 'would create' 'a System Restore point'; return }
    Pink "`n  Creating a restore point (this can take a minute)..."
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
    try {
        if (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue) {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description 'Before Lerxna Optimizer' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        } else {
            Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'Enable' -Arguments @{ Drive = "$env:SystemDrive\" } -ErrorAction SilentlyContinue | Out-Null
            $r = Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'CreateRestorePoint' `
                -Arguments @{ Description = 'Before Lerxna Optimizer'; RestorePointType = [uint32]12; EventType = [uint32]100 } -ErrorAction Stop
            if ($r.ReturnValue -ne 0) { throw "Windows returned code $($r.ReturnValue)" }
        }
        Done "Restore point created. You can roll back from: Control Panel > Recovery > Open System Restore."
    } catch {
        Warn "Could not create a restore point: $($_.Exception.Message)"
        Info "System Protection might be turned off for $($env:SystemDrive). You can still continue."
    }
}

# ============================================================
# TWEAK DEFINITIONS
# ============================================================
# Each tweak: Cat, Title, Q (question), Note, Rec (recommended),
# Caution, Show (only asked if true), Interactive, Explorer,
# Reboot, Action (scriptblock)

$Script:Categories = @(
    'Performance'
    'Gaming'
    'Privacy & Telemetry'
    'Ads, Tips & Suggestions'
    'Appearance & Explorer'
    'Apps & Bloatware'
    'Windows Update'
    'Advanced (power users)'
)

$Script:TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\|Microsoft Compatibility Appraiser'
    '\Microsoft\Windows\Application Experience\|Microsoft Compatibility Appraiser Exp'
    '\Microsoft\Windows\Application Experience\|ProgramDataUpdater'
    '\Microsoft\Windows\Customer Experience Improvement Program\|Consolidator'
    '\Microsoft\Windows\Customer Experience Improvement Program\|UsbCeip'
    '\Microsoft\Windows\Autochk\|Proxy'
    '\Microsoft\Windows\DiskDiagnostic\|Microsoft-Windows-DiskDiagnosticDataCollector'
    '\Microsoft\Windows\Feedback\Siuf\|DmClient'
    '\Microsoft\Windows\Feedback\Siuf\|DmClientOnScenarioDownload'
    '\Microsoft\Windows\Sustainability\|SustainabilityTelemetry'
)

# Built-in apps. Useful = $true means "Remove the junk only" keeps it.
$Script:BloatApps = @(
    @{ Id = 'Microsoft.3DBuilder';                     Name = '3D Builder' }
    @{ Id = 'Microsoft.BingWeather';                   Name = 'Weather' }
    @{ Id = 'Microsoft.BingNews';                      Name = 'News' }
    @{ Id = 'Microsoft.BingFinance';                   Name = 'Money' }
    @{ Id = 'Microsoft.BingSports';                    Name = 'Sports' }
    @{ Id = 'Microsoft.BingTravel';                    Name = 'Travel' }
    @{ Id = 'Microsoft.BingFoodAndDrink';              Name = 'Food & Drink' }
    @{ Id = 'Microsoft.BingHealthAndFitness';          Name = 'Health & Fitness' }
    @{ Id = 'Microsoft.BingSearch';                    Name = 'Bing Search' }
    @{ Id = 'Microsoft.GetHelp';                       Name = 'Get Help' }
    @{ Id = 'Microsoft.Getstarted';                    Name = 'Tips' }
    @{ Id = 'Microsoft.MicrosoftOfficeHub';            Name = 'Microsoft 365 (Office) hub' }
    @{ Id = 'Microsoft.MicrosoftSolitaireCollection';  Name = 'Solitaire Collection' }
    @{ Id = 'Microsoft.MixedReality.Portal';           Name = 'Mixed Reality Portal' }
    @{ Id = 'Microsoft.Office.OneNote';                Name = 'OneNote (Store version)' }
    @{ Id = 'Microsoft.OneConnect';                    Name = 'Mobile Plans' }
    @{ Id = 'Microsoft.People';                        Name = 'People' }
    @{ Id = 'Microsoft.Print3D';                       Name = 'Print 3D' }
    @{ Id = 'Microsoft.SkypeApp';                      Name = 'Skype' }
    @{ Id = 'microsoft.windowscommunicationsapps';     Name = 'Mail & Calendar (old)' }
    @{ Id = 'Microsoft.WindowsFeedbackHub';            Name = 'Feedback Hub' }
    @{ Id = 'Microsoft.WindowsMaps';                   Name = 'Maps' }
    @{ Id = 'Microsoft.ZuneVideo';                     Name = 'Movies & TV' }
    @{ Id = 'Microsoft.MSPaint';                       Name = 'Paint 3D' }
    @{ Id = 'Microsoft.Whiteboard';                    Name = 'Whiteboard' }
    @{ Id = 'MicrosoftTeams';                          Name = 'Teams (personal, old)' }
    @{ Id = 'MSTeams';                                 Name = 'Teams (new)' }
    @{ Id = 'Microsoft.549981C3F5F10';                 Name = 'Cortana' }
    @{ Id = 'Microsoft.PowerAutomateDesktop';          Name = 'Power Automate' }
    @{ Id = 'Clipchamp.Clipchamp';                     Name = 'Clipchamp' }
    @{ Id = 'Microsoft.MicrosoftJournal';              Name = 'Journal' }
    @{ Id = 'Microsoft.Windows.DevHome';               Name = 'Dev Home' }
    @{ Id = 'Microsoft.Copilot';                       Name = 'Copilot app' }
    @{ Id = 'MicrosoftCorporationII.MicrosoftFamily';  Name = 'Microsoft Family' }
    @{ Id = '*CandyCrush*';                            Name = 'Candy Crush games' }
    @{ Id = '*BubbleWitch*';                           Name = 'Bubble Witch' }
    @{ Id = '*MarchofEmpires*';                        Name = 'March of Empires' }
    @{ Id = '*Disney*';                                Name = 'Disney+' }
    @{ Id = '*TikTok*';                                Name = 'TikTok' }
    @{ Id = '*Facebook*';                              Name = 'Facebook' }
    @{ Id = '*Instagram*';                             Name = 'Instagram' }
    @{ Id = '*LinkedIn*';                              Name = 'LinkedIn' }
    @{ Id = 'AmazonVideo.PrimeVideo';                  Name = 'Prime Video' }
    @{ Id = '*McAfee*';                                Name = 'McAfee (trial)' }
    # "Useful" apps - only removed if you pick them
    @{ Id = 'Microsoft.MicrosoftStickyNotes';          Name = 'Sticky Notes';        Useful = $true }
    @{ Id = 'Microsoft.Todos';                         Name = 'Microsoft To Do';     Useful = $true }
    @{ Id = 'Microsoft.WindowsAlarms';                 Name = 'Clock / Alarms';      Useful = $true }
    @{ Id = 'Microsoft.WindowsCamera';                 Name = 'Camera';              Useful = $true }
    @{ Id = 'Microsoft.WindowsSoundRecorder';          Name = 'Sound Recorder';      Useful = $true }
    @{ Id = 'Microsoft.YourPhone';                     Name = 'Phone Link';          Useful = $true }
    @{ Id = 'Microsoft.ZuneMusic';                     Name = 'Media Player';        Useful = $true }
    @{ Id = 'Microsoft.OutlookForWindows';             Name = 'Outlook (new)';       Useful = $true }
    @{ Id = 'MicrosoftCorporationII.QuickAssist';      Name = 'Quick Assist';        Useful = $true }
    @{ Id = '*Netflix*';                               Name = 'Netflix';             Useful = $true }
    @{ Id = '*Spotify*';                               Name = 'Spotify';             Useful = $true }
)

# Xbox Identity Provider and Xbox TCUI are left alone on purpose:
# many PC games need them to sign in.
$Script:XboxApps = @(
    @{ Id = 'Microsoft.GamingApp';                Name = 'Xbox app (Game Pass)'; Useful = $true }
    @{ Id = 'Microsoft.XboxApp';                  Name = 'Xbox Console Companion' }
    @{ Id = 'Microsoft.XboxGamingOverlay';        Name = 'Xbox Game Bar';        Useful = $true }
    @{ Id = 'Microsoft.XboxGameOverlay';          Name = 'Xbox Game Overlay' }
    @{ Id = 'Microsoft.XboxSpeechToTextOverlay';  Name = 'Xbox Speech-to-Text overlay' }
)

function Get-BloatServiceTargets {
    $targets = New-Object System.Collections.Generic.List[object]
    $services = @(
        @{ N = 'AdobeARMservice'; L = 'Adobe Acrobat update service'; T = 'Disabled' }
        @{ N = 'AUEPLauncher';    L = 'AMD User Experience Program';  T = 'Disabled' }
        @{ N = 'GamingServices';  L = 'Xbox Gaming Services (to Manual)'; T = 'Manual' }
        @{ N = 'GameInputSvc';    L = 'GameInput service (to Manual)';    T = 'Manual' }
    )
    foreach ($svc in $services) {
        $found = Get-Service -Name $svc.N -ErrorAction SilentlyContinue
        if ($found -and $found.StartType -ne $svc.T -and $found.StartType -ne 'Disabled') {
            $targets.Add(@{ Kind = 'Service'; Name = $svc.N; Label = $svc.L; StartType = $svc.T })
        }
    }
    $tasks = @(Get-AllTasks | Where-Object { $_.State -ne 'Disabled' })
    $patterns = @(
        @{ P = '*Xbox*';                           L = 'Xbox background tasks' }
        @{ P = 'XblGameSaveTask';                  L = 'Xbox game save sync task' }
        @{ P = 'MicrosoftEdgeUpdateTaskMachine*';  L = 'Edge updater tasks' }
        @{ P = 'Adobe Acrobat Update Task';        L = 'Adobe updater task' }
        @{ P = 'Launch Adobe CCXProcess';          L = 'Adobe CCXProcess task' }
        @{ P = 'AMDInstallUEP';                    L = 'AMD telemetry tasks' }
        @{ P = 'StartAUEP';                        L = 'AMD telemetry tasks' }
        @{ P = 'NvTmRep*';                         L = 'NVIDIA telemetry tasks' }
        @{ P = 'NvTmMon*';                         L = 'NVIDIA telemetry tasks' }
    )
    foreach ($p in $patterns) {
        foreach ($t in @($tasks | Where-Object { $_.TaskName -like $p.P })) {
            $targets.Add(@{ Kind = 'Task'; Name = $t.TaskName; Path = $t.TaskPath; Label = $p.L })
        }
    }
    return $targets
}

function Remove-AppxSafe {
    param([string]$Pattern, [string]$Name = $Pattern)
    if ($Script:Preview) { Add-PreviewLine 'would remove' "app: $Name"; return }
    Save-JournalChange @{ Kind = 'Note'; Text = "Removed app '$Name' - reinstall it from the Microsoft Store if you want it back" }
    foreach ($p in @($Script:Sys.Appx | Where-Object { $_.Name -like $Pattern })) {
        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop }
        catch {
            try { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
            catch { Write-Log "APPX FAILED $($p.Name): $($_.Exception.Message)" }
        }
    }
    if ($null -eq $Script:Provisioned) {
        $Script:Provisioned = @()
        if ($Script:Has.Provisioned) { try { $Script:Provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) } catch {} }
    }
    foreach ($pp in @($Script:Provisioned | Where-Object { $_.DisplayName -like $Pattern })) {
        try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null } catch {}
    }
    Write-Log "APPX removed $Pattern"
}

function Invoke-AppRemoval {
    param($List, [string]$Title)
    $found = @($List | Where-Object {
        $pattern = $_.Id
        @($Script:Sys.Appx | Where-Object { $_.Name -like $pattern }).Count -gt 0
    })
    if ($found.Count -eq 0) {
        Info "None of these $Title apps are installed - nothing to remove."
        $Script:TweakCancelled = $true
        return
    }
    Write-Host ""
    Write-Host "   Found $($found.Count) $Title app(s) on this PC:" -ForegroundColor White
    $i = 0
    foreach ($a in $found) {
        $i++
        $tag = if ($a.Useful) { '   (useful to some people)' } else { '' }
        Write-Host ("   {0,3}. {1}" -f $i, $a.Name) -NoNewline
        Write-Host $tag -ForegroundColor DarkYellow
    }
    if ($Script:Preview) {
        Add-PreviewLine 'would ask' "which of these $($found.Count) apps to remove: $(($found | ForEach-Object { $_.Name }) -join ', ')"
        return
    }
    Write-Host ""
    Write-Host "   [1] Remove the junk only (keeps the ones marked useful)"
    Write-Host "   [2] Ask me about each one"
    Write-Host "   [3] Type the numbers to remove"
    Write-Host "   [4] Remove everything listed"
    Write-Host "   [0] Cancel"
    $c = Read-Choice "Choose [0-4]:" @('0', '1', '2', '3', '4')
    $toRemove = @()
    switch ($c) {
        '1' { $toRemove = @($found | Where-Object { -not $_.Useful }) }
        '2' { foreach ($a in $found) { if (Ask "Remove $($a.Name)?") { $toRemove += $a } } }
        '3' {
            $txt = Read-Host "  Numbers to remove (e.g. 1,3,5-7)"
            foreach ($n in @(Parse-Selection $txt $found.Count)) { $toRemove += $found[$n - 1] }
        }
        '4' { $toRemove = $found }
    }
    if ($toRemove.Count -eq 0) { $Script:TweakCancelled = $true; return }
    foreach ($a in $toRemove) {
        Write-Host "     Removing $($a.Name)..." -ForegroundColor DarkGray
        Remove-AppxSafe $a.Id $a.Name
    }
    $Script:Sys.Appx = @(Get-InstalledAppx)
    Info "Removed $($toRemove.Count) app(s). You can reinstall any of them from the Microsoft Store."
}

function Initialize-Tweaks {
    $s    = $Script:Sys
    $hib  = Get-HiberInfo
    $bloatTargets = @(Get-BloatServiceTargets)
    $bloatLabels  = @($bloatTargets | ForEach-Object { $_.Label } | Select-Object -Unique)
    $laptopWarn   = if ($s.IsLaptop) { "`nYou're on a laptop: this uses more battery." } else { '' }
    $diskNote     = if ($s.IsHDD) { "Your Windows drive is a hard drive (HDD) - SysMain helps apps open faster there. Keeping it is recommended." }
                    elseif ($s.IsSSD) { "Your Windows drive is an SSD - SysMain gives very little benefit here." }
                    else { "Helps on hard drives, does very little on SSDs." }

    $Script:Tweaks = @(
        # ---------------- PERFORMANCE ----------------
        @{ Cat = 'Performance'; Title = 'Visual effects'; Rec = $true; Explorer = $true
           Q = 'Optimize visual effects? (turns off animations, keeps thumbnails and smooth fonts)'
           Note = 'Makes menus and windows feel snappier.'
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
               Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
               Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
               Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1' 'String'
               Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
               Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
               Set-Reg $Script:AdvKey 'TaskbarAnimations' 0
               Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
           } }

        @{ Cat = 'Performance'; Title = 'High Performance power plan'; Rec = (-not $s.IsLaptop)
           Q = 'Switch to the High Performance power plan?'
           Note = "Keeps the CPU ready at full speed and stops sleep while plugged in.$laptopWarn"
           Action = {
               if (-not (Set-PowerScheme '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' 'High performance')) {
                   throw "High Performance isn't available on this PC (common on laptops with Modern Standby)."
               }
               Set-PowerTimeoutAC 'STANDBYIDLE' 'Sleep after' 0
               Set-PowerTimeoutAC 'HIBERNATEIDLE' 'Hibernate after' 0
           } }

        @{ Cat = 'Performance'; Title = 'Ultimate Performance power plan'; Show = (-not $s.IsLaptop)
           Q = 'Use the Ultimate Performance plan instead? (desktops only)'
           Note = "A step above High Performance - removes tiny power-saving delays.`nUses a bit more power at idle."
           Action = {
               if (-not (Set-PowerScheme 'e9a42b02-d5df-448d-aa00-03f14749eb61' 'Ultimate Performance')) {
                   throw "Ultimate Performance isn't available on this edition of Windows."
               }
               Set-PowerTimeoutAC 'STANDBYIDLE' 'Sleep after' 0
           } }

        @{ Cat = 'Performance'; Title = 'Turn off hibernation'; Show = $hib.On; Rec = (-not $s.IsLaptop)
           Q = "Turn off hibernation? (frees about $($hib.GB) GB of disk space)"
           Note = "Deletes hiberfil.sys. Also turns off Fast Startup.$(if ($s.IsLaptop) { "`nYou're on a laptop: you won't be able to hibernate anymore." })"
           Action = { Set-Hibernation $false } }

        @{ Cat = 'Performance'; Title = 'Turn off Fast Startup'; Show = $hib.On
           Q = 'Turn off Fast Startup?'
           Note = "Makes 'Shut down' a real full shutdown. Fixes a lot of driver/update weirdness`nbut boot takes a few seconds longer."
           Action = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 } }

        @{ Cat = 'Performance'; Title = 'Disable SysMain (Superfetch)'; Show = [bool](Get-Service 'SysMain' -ErrorAction SilentlyContinue); Caution = $s.IsHDD
           Q = 'Disable SysMain (Superfetch)?'
           Note = $diskNote
           Action = { Set-ServiceStartup 'SysMain' 'Disabled' -Stop } }

        @{ Cat = 'Performance'; Title = 'Disable search indexing'; Caution = $true; Show = [bool](Get-Service 'WSearch' -ErrorAction SilentlyContinue)
           Q = 'Disable Windows Search indexing?'
           Note = "Stops background disk activity, but searching files in Start/Explorer/Outlook gets slower."
           Action = { Set-ServiceStartup 'WSearch' 'Disabled' -Stop } }

        @{ Cat = 'Performance'; Title = 'Stop background Store apps'
           Q = 'Stop Store apps from running in the background?'
           Note = "Saves RAM/CPU. Some Store apps (Mail, Phone Link, etc.) won't notify you until opened."
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 0
           } }

        @{ Cat = 'Performance'; Title = 'Stop sharing updates with other PCs'; Rec = $true
           Q = 'Stop Windows from uploading updates to other PCs on the internet? (Delivery Optimization)'
           Note = 'Saves upload bandwidth. Updates still download normally.'
           Action = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 } }

        @{ Cat = 'Performance'; Title = 'Faster shutdown'; Rec = $true
           Q = 'Make shutdown faster? (waits less for frozen apps/services)'
           Action = {
               Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' 'String'
               Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '5000' 'String'
               Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '3000' 'String'
           } }

        @{ Cat = 'Performance'; Title = "Don't auto-restart on blue screen"; Rec = $true
           Q = "Don't auto-restart on a blue screen (BSOD)?"
           Note = 'So you can actually read the error code instead of it rebooting instantly.'
           Action = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'AutoReboot' 0 } }

        # ---------------- GAMING ----------------
        @{ Cat = 'Gaming'; Title = 'Game Mode on'; Rec = $true
           Q = 'Turn on Game Mode?'
           Note = 'Windows gives games priority and pauses some background work while you play.'
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
               Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
           } }

        @{ Cat = 'Gaming'; Title = 'Disable Game DVR background recording'; Rec = $true
           Q = 'Disable Xbox Game Bar background recording (Game DVR)?'
           Note = "Background recording costs FPS. Use OBS/ShadowPlay/ReLive if you want clips."
           Action = {
               Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
           } }

        @{ Cat = 'Gaming'; Title = 'Prioritize games and audio'; Rec = $true
           Q = 'Prioritize games and audio over background tasks? (removes network throttling)'
           Action = {
               $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
               Set-Reg $mm 'NetworkThrottlingIndex' 4294967295   # 0xFFFFFFFF = no throttling
               Set-Reg $mm 'SystemResponsiveness' 10
               Set-Reg "$mm\Tasks\Games" 'GPU Priority' 8
               Set-Reg "$mm\Tasks\Games" 'Priority' 6
               Set-Reg "$mm\Tasks\Games" 'Scheduling Category' 'High' 'String'
               Set-Reg "$mm\Tasks\Games" 'SFIO Priority' 'High' 'String'
           } }

        @{ Cat = 'Gaming'; Title = 'Hardware-accelerated GPU scheduling'; Reboot = $true
           Show = ($s.Build -ge 19041 -and $s.HasDedicated)
           Q = 'Turn on Hardware-accelerated GPU scheduling (HAGS)?'
           Note = "Can lower input lag; needed for DLSS Frame Generation. Needs a restart.`nOn a few older GPUs/drivers it can cause stutter - you can turn it off in Settings > Display > Graphics."
           Action = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 } }

        @{ Cat = 'Gaming'; Title = 'Turn off mouse acceleration'
           Q = "Turn off mouse acceleration ('Enhance pointer precision')?"
           Note = "Makes aim consistent - mouse moves the same distance no matter how fast you flick.`nTakes effect after you sign out."
           Action = {
               Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
               Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
               Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
           } }

        @{ Cat = 'Gaming'; Title = 'Disable Sticky Keys popup'; Rec = $true
           Q = 'Stop the Sticky Keys / Filter Keys popup when you spam Shift?'
           Action = {
               Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
               Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys' 'Flags' '58' 'String'
               Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
           } }

        # ---------------- PRIVACY ----------------
        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable telemetry'; Rec = $true
           Q = 'Disable Windows telemetry and data collection?'
           Note = "Turns off the DiagTrack service and the telemetry scheduled tasks.`nAlso turns off cross-device features like Nearby Sharing."
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
               Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowDeviceNameInTelemetry' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableCdp' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable' 0
               Set-ServiceStartup 'DiagTrack' 'Disabled' -Stop
               foreach ($t in $Script:TelemetryTasks) {
                   $parts = $t -split '\|'
                   Disable-TaskSafe $parts[0] $parts[1]
               }
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable activity history'; Rec = $true
           Q = 'Disable activity history (Timeline / app & file tracking)?'
           Action = {
               $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
               Set-Reg $p 'EnableActivityFeed' 0
               Set-Reg $p 'PublishUserActivities' 0
               Set-Reg $p 'UploadUserActivities' 0
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable advertising ID'; Rec = $true
           Q = 'Disable your advertising ID and personalized "tailored experiences"?'
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
               Set-Reg 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Stop typing/inking data collection'; Rec = $true
           Q = 'Stop Windows collecting your typing and handwriting data?'
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
               Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
               Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
               Set-Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable Cortana & Bing search'; Rec = $true
           Q = 'Disable Cortana and Bing web results in Start menu search?'
           Note = 'Start search will only search your PC - faster and no web junk.'
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
               Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable Windows AI / Recall / Copilot'; Rec = $true
           Q = 'Disable Windows AI features (Recall, Copilot)?'
           Note = "Turns off Recall snapshots and the Copilot taskbar button.`nTo remove the Copilot app itself, use 'Remove built-in apps' later."
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
               Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
               Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
               Set-Reg $Script:AdvKey 'ShowCopilotButton' 0
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable location services'; Caution = $true
           Q = 'Disable ALL location services?'
           Note = 'Weather, Maps, Find My Device and automatic time zone will stop working.'
           Action = {
               $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
               Set-Reg $p 'DisableLocation' 1
               Set-Reg $p 'DisableLocationScripting' 1
               Set-Reg $p 'DisableWindowsLocationProvider' 1
               Set-Reg $p 'DisableSensors' 1
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}' 'Value' 'Deny' 'String'
               Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}' 'SensorPermissionState' 0
               Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
               Set-ServiceStartup 'lfsvc' 'Disabled' -Stop
               Disable-TaskSafe '\Microsoft\Windows\Location\' 'WindowsActionDialog'
               Disable-TaskSafe '\Microsoft\Windows\Location\' 'Notifications'
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Disable Windows Error Reporting'
           Q = 'Stop sending crash reports to Microsoft (Windows Error Reporting)?'
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
           } }

        @{ Cat = 'Privacy & Telemetry'; Title = 'Stop Edge running in the background'; Show = $s.HasEdge; Rec = $true
           Q = 'Stop Microsoft Edge pre-loading at boot and running after you close it?'
           Note = "Turns off Startup Boost, background mode and shopping popups.`nEdge will say 'managed by your organization' - that's just these settings."
           Action = {
               $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
               Set-Reg $e 'StartupBoostEnabled' 0
               Set-Reg $e 'BackgroundModeEnabled' 0
               Set-Reg $e 'EdgeShoppingAssistantEnabled' 0
               Set-Reg $e 'ShowRecommendationsEnabled' 0
               Set-Reg $e 'HideFirstRunExperience' 1
           } }

        # ---------------- ADS ----------------
        @{ Cat = 'Ads, Tips & Suggestions'; Title = 'Disable ads & suggestions'; Rec = $true; Explorer = $true
           Q = 'Disable Windows ads, tips, "suggested" apps and lock screen promotions?'
           Note = 'Also stops Windows silently installing promoted apps like Candy Crush.'
           Action = {
               $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
               foreach ($v in @('SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                                'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled',
                                'SubscribedContent-310093Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled',
                                'SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled',
                                'RotatingLockScreenOverlayEnabled')) {
                   Set-Reg $cdm $v 0
               }
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
               Set-Reg $Script:AdvKey 'ShowSyncProviderNotifications' 0
               Set-Reg $Script:AdvKey 'Start_IrisRecommendations' 0
               Set-Reg $Script:AdvKey 'Start_AccountNotifications' 0
               Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested' 'Enabled' 0
           } }

        @{ Cat = 'Ads, Tips & Suggestions'; Title = 'Disable Widgets / News feed'; Rec = $true; Explorer = $true
           Q = 'Disable Widgets and the News & Interests feed on the taskbar?'
           Note = 'Stops the news/weather feed that runs in the background.'
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
               Set-Reg $Script:AdvKey 'TaskbarDa' 0
           } }

        # ---------------- APPEARANCE ----------------
        @{ Cat = 'Appearance & Explorer'; Title = 'Dark mode'; Explorer = $true
           Q = 'Enable dark mode?'
           Action = {
               $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
               Set-Reg $p 'AppsUseLightTheme' 0
               Set-Reg $p 'SystemUsesLightTheme' 0
               Set-Reg $p 'ColorPrevalence' 0
           } }

        @{ Cat = 'Appearance & Explorer'; Title = 'File Explorer setup'; Rec = $true; Explorer = $true
           Q = 'Set up File Explorer? (show file extensions + hidden files, open to This PC)'
           Note = 'Showing extensions helps you spot fake files like "photo.jpg.exe".'
           Action = {
               Set-Reg $Script:AdvKey 'HideFileExt' 0
               Set-Reg $Script:AdvKey 'Hidden' 1
               Set-Reg $Script:AdvKey 'LaunchTo' 1
           } }

        @{ Cat = 'Appearance & Explorer'; Title = 'Hide recent files in Quick Access'; Explorer = $true
           Q = 'Hide recent files and frequent folders in Explorer / Start?'
           Note = 'More privacy if other people use your PC.'
           Action = {
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowRecent' 0
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowFrequent' 0
               Set-Reg $Script:AdvKey 'Start_TrackDocs' 0
           } }

        @{ Cat = 'Appearance & Explorer'; Title = 'Taskbar cleanup'; Explorer = $true
           Q = $(if ($s.IsWin11) { 'Clean up the taskbar? (align left, search icon only, hide Task View and Chat)' } else { 'Clean up the taskbar? (search icon only, hide Task View)' })
           Action = {
               if ($Script:Sys.IsWin11) {
                   Set-Reg $Script:AdvKey 'TaskbarAl' 0
                   Set-Reg $Script:AdvKey 'TaskbarMn' 0
               }
               Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
               Set-Reg $Script:AdvKey 'ShowTaskViewButton' 0
           } }

        @{ Cat = 'Appearance & Explorer'; Title = 'Classic right-click menu'; Show = $s.IsWin11; Explorer = $true
           Q = 'Bring back the classic (full) right-click menu?'
           Note = "No more clicking 'Show more options' every time."
           Action = { Set-Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '' '' 'String' } }

        @{ Cat = 'Appearance & Explorer'; Title = "'End task' on taskbar"; Show = ($s.Build -ge 22631); Rec = $true
           Q = "Add 'End task' to the taskbar right-click menu?"
           Note = 'Kill frozen apps without opening Task Manager.'
           Action = { Set-Reg "$($Script:AdvKey)\TaskbarDeveloperSettings" 'TaskbarEndTask' 1 } }

        # ---------------- APPS ----------------
        @{ Cat = 'Apps & Bloatware'; Title = 'Remove built-in bloat apps'; Interactive = $true; Show = $Script:Has.Appx
           Q = 'Remove built-in bloat apps? (shows you only the ones installed on this PC)'
           Action = { Invoke-AppRemoval -List $Script:BloatApps -Title 'built-in' } }

        @{ Cat = 'Apps & Bloatware'; Title = 'Remove Xbox apps'; Interactive = $true; Show = $s.HasXbox; Caution = $true
           Q = 'Remove Xbox apps?'
           Note = "Don't do this if you use Game Pass, Minecraft launcher or Game Bar.`nXbox sign-in components are kept so games still log in."
           Action = { Invoke-AppRemoval -List $Script:XboxApps -Title 'Xbox' } }

        @{ Cat = 'Apps & Bloatware'; Title = 'Disable background updaters & telemetry'; Show = ($bloatTargets.Count -gt 0); Rec = $true
           Q = 'Disable background updaters/telemetry found on your PC?'
           Note = "Found: $($bloatLabels -join ', ')`nApps still update when you open them."
           Action = {
               foreach ($t in @(Get-BloatServiceTargets)) {
                   if ($t.Kind -eq 'Service') { Set-ServiceStartup $t.Name $t.StartType -Stop:($t.StartType -eq 'Disabled') }
                   else { Disable-TaskSafe $t.Path $t.Name }
               }
           } }

        @{ Cat = 'Apps & Bloatware'; Title = 'Remove OneDrive'; Show = $s.HasOneDrive; Caution = $true; Explorer = $true; NoRoundTrip = $true
           Q = 'Uninstall OneDrive and stop it coming back?'
           Note = "Make sure everything is synced first. Files that are 'online-only' won't be on this PC after.`nYour OneDrive folder and local files are not deleted."
           Action = {
               Invoke-Step 'Close and uninstall OneDrive (reinstall it from microsoft.com/onedrive if you want it back)' {
                   Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
                   $setup = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
                   if (-not (Test-Path $setup)) { $setup = "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
                   if (Test-Path $setup) {
                       Start-Process $setup '/uninstall' -NoNewWindow -Wait
                   } else {
                       $un = Get-ItemProperty -Path $Script:UninstallKeys -ErrorAction SilentlyContinue |
                             Where-Object { $_.DisplayName -like 'Microsoft OneDrive*' -and $_.UninstallString } | Select-Object -First 1
                       if ($un) { Start-Process 'cmd.exe' -ArgumentList "/c $($un.UninstallString)" -WindowStyle Hidden -Wait }
                   }
               }
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
               Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSync' 1
               Remove-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
               foreach ($odt in @(Get-AllTasks | Where-Object { $_.TaskName -like 'OneDrive*' })) {
                   Disable-TaskSafe $odt.TaskPath $odt.TaskName
               }
           } }

        # ---------------- WINDOWS UPDATE ----------------
        @{ Cat = 'Windows Update'; Title = 'No forced restarts'; Rec = $true
           Q = "Stop Windows Update from restarting your PC while you're signed in?"
           Note = "Updates still install - you just choose when to restart.`nSettings may say 'some settings are managed by your organization'."
           Action = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1 } }

        @{ Cat = 'Windows Update'; Title = 'Exclude drivers from Windows Update'
           Q = 'Stop Windows Update from installing drivers?'
           Note = "Useful if Windows keeps replacing your GPU driver with an older one.`nYou'll need to update drivers yourself (NVIDIA/AMD/Intel apps)."
           Action = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1 } }

        # ---------------- ADVANCED ----------------
        @{ Cat = 'Advanced (power users)'; Title = 'Terminals always as admin'; Caution = $true
           Q = 'Make PowerShell, CMD and Windows Terminal always run as Administrator?'
           Note = "Every terminal window will show a UAC prompt, and apps that run scripts may too.`nCan be undone from the Undo menu."
           Action = {
               $layers = @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers', 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers')
               foreach ($exe in (Get-TerminalExes)) { foreach ($l in $layers) { Set-Reg $l $exe 'RUNASADMIN' 'String' } }
           } }

        @{ Cat = 'Advanced (power users)'; Title = 'Block touch keyboard (TextInputHost)'; Caution = $true
           Q = 'Block the touch keyboard process (TextInputHost)?'
           Note = "WARNING: this also breaks the emoji panel (Win + .) and clipboard history (Win + V).`nDon't use on touchscreens. Can be undone from the Undo menu."
           Action = {
               Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\TextInputHost.exe' 'Debugger' 'invalid' 'String'
           } }
    )
}

function Get-TerminalExes {
    return @(
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        "$env:SystemRoot\System32\cmd.exe"
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
    )
}

function Invoke-Tweak {
    param($T)
    $Script:TweakCancelled = $false

    if ($Script:Preview) {
        Pink "     Preview: $($T.Title)"
        $Script:PreviewLog.Add("")
        $Script:PreviewLog.Add("== $($T.Title) ==")
        try {
            & $T.Action | Out-Null
            $Script:Previewed.Add($T.Title)
        } catch {
            Warn "$($T.Title): $($_.Exception.Message)"
            $Script:Failed.Add($T.Title)
        }
        return
    }

    Pink "     Applying: $($T.Title)..."
    $errorsBefore = $Script:ChangeErrors
    Start-TweakRecord $T.Title ([bool]$T.Explorer)
    try {
        & $T.Action | Out-Null
        if ($Script:TweakCancelled) {
            Skip $T.Title
            $Script:Skipped.Add($T.Title)
            return
        }
        if ($Script:ChangeErrors -gt $errorsBefore) {
            Warn "$($T.Title): $($Script:ChangeErrors - $errorsBefore) setting(s) couldn't be changed (Windows blocked them). The rest were applied."
        }
        Done $T.Title
        $Script:Applied.Add($T.Title)
        if ($T.Explorer) { $Script:NeedsExplorerRestart = $true }
        if ($T.Reboot)   { $Script:NeedsReboot = $true }
    } catch {
        Warn "$($T.Title) failed: $($_.Exception.Message)"
        $Script:Failed.Add($T.Title)
    } finally {
        $Script:CurrentRecord = $null
    }
}

# Shows every change every tweak would make, without changing anything
function Invoke-PreviewAll {
    param($Tweaks)
    $wasPreview = $Script:Preview
    $Script:Preview = $true
    try {
        foreach ($cat in $Script:Categories) {
            $items = @($Tweaks | Where-Object { $_.Cat -eq $cat })
            if ($items.Count -eq 0) { continue }
            Section "$cat (preview)"
            foreach ($t in $items) { Invoke-Tweak $t }
        }
        Save-PreviewReport
    } finally {
        $Script:Preview = $wasPreview
    }
}

function Save-PreviewReport {
    if ($Script:PreviewLog.Count -eq 0) { return }
    $file = Join-Path $Script:DataDir ("preview_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $header = @(
        "Lerxna Optimizer v$($Script:Version) - preview report ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
        "Nothing was changed. This is what each option WOULD do on this PC."
        ""
    )
    try {
        Set-Content -LiteralPath $file -Value (@($header) + @($Script:PreviewLog)) -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Done "Preview saved to: $file"
        $Script:PreviewLog.Clear()
    } catch {}
}

function Invoke-TweakWizard {
    Initialize-Tweaks
    $visible = @($Script:Tweaks | Where-Object { $null -eq $_.Show -or $_.Show })

    Section "System Tweaks ($($visible.Count) options for your PC)"
    Write-Host "   How do you want to go through them?"
    Write-Host ""
    Write-Host "   [1] Ask me about every tweak (Y/N for each)"
    Write-Host "   [2] Recommended - auto-apply the safe ones, ask me about the rest"
    Write-Host "   [3] Express - apply only the recommended ones, don't ask anything else"
    Write-Host "   [4] Preview - show me exactly what every tweak would change (changes nothing)"
    Write-Host "   [0] Back"
    if ($Script:Preview) { Write-Host "   (Preview mode is ON - whatever you pick, nothing will be changed)" -ForegroundColor Cyan }
    $mode = Read-Choice "Choose [0-4]:" @('0', '1', '2', '3', '4')
    if ($mode -eq '0') { return }
    if ($mode -eq '4') { Invoke-PreviewAll $visible; return }

    if ($mode -ne '1') {
        $autoList = @($visible | Where-Object { $_.Rec -and -not $_.Interactive })
        Write-Host ""
        $verb = if ($Script:Preview) { 'previewed' } else { 'applied automatically' }
        Write-Host "   These $($autoList.Count) recommended tweaks will be $($verb):" -ForegroundColor White
        foreach ($t in $autoList) { Write-Host "     + $($t.Title)" -ForegroundColor Green }
        if (-not (Ask "Go ahead?")) { return }
    }

    foreach ($cat in $Script:Categories) {
        $items = @($visible | Where-Object { $_.Cat -eq $cat })
        if ($items.Count -eq 0) { continue }

        $auto = @(); $ask = @()
        foreach ($t in $items) {
            if ($mode -ne '1' -and $t.Rec -and -not $t.Interactive) { $auto += $t } else { $ask += $t }
        }

        Section "$cat"
        foreach ($t in $auto) { Invoke-Tweak $t }

        if ($ask.Count -eq 0) { continue }
        if ($mode -eq '3') {
            foreach ($t in $ask) { $Script:Skipped.Add($t.Title) }
            Info "$($ask.Count) optional tweak(s) here were left alone (Express mode)."
            continue
        }

        if ($ask.Count -gt 1) {
            $label = if ($auto.Count) { "Look at the other $($ask.Count) $cat options?" } else { "Look at the $($ask.Count) $cat options?" }
            if (-not (Ask $label)) {
                foreach ($t in $ask) { Skip $t.Title; $Script:Skipped.Add($t.Title) }
                continue
            }
        }

        foreach ($t in $ask) {
            $tag = if ($t.Rec) { 'REC' } elseif ($t.Caution) { 'CAUTION' } else { 'CHOICE' }
            if (Ask $t.Q $tag $t.Note) { Invoke-Tweak $t }
            else { Skip $t.Title; $Script:Skipped.Add($t.Title) }
        }
    }

    if ($Script:NeedsExplorerRestart) { Restart-Explorer }
    Write-Host ""
    if ($Script:Preview) { Save-PreviewReport; Done "Preview finished - nothing was changed." }
    else { Done "System tweaks finished. Any of them can be undone from the Undo menu." }
}

# ============================================================
# STARTUP & BACKGROUND APPS SCANNER
# ============================================================

# What we know about common startup apps. First match wins, so the
# "Keep" entries come first, then "Choice", then "Disable".
$Script:KnownApps = @(
    # ---- KEEP ----
    @{ P = 'SecurityHealth|Windows Defender|MsMpEng|WindowsSecurity'; R = 'Keep'; N = 'Windows Security - keeps you protected' }
    @{ P = 'Avast|\bAVG\b|Avira|Bitdefender|Norton|McAfee|Kaspersky|\bESET\b|Malwarebytes|Sophos|Webroot|Trend ?Micro|F-Secure|Comodo|360 ?Total'; R = 'Keep'; N = 'Antivirus / security software' }
    @{ P = 'vgtray|vgc\.exe|Vanguard'; R = 'Keep'; N = 'Riot Vanguard anti-cheat - required for Valorant / League' }
    @{ P = 'Realtek|RtkAud|RAVCpl|RAVBg|Nahimic|Dolby|MaxxAudio|Waves|Sonic Studio|Sound ?Blaster|Creative Labs|\bDTS\b'; R = 'Keep'; N = 'Audio driver / sound enhancements' }
    @{ P = 'Synaptics|SynTP|\bELAN\b|ETDCtrl|Alps|Precision ?Touchpad'; R = 'Keep'; N = 'Touchpad driver' }
    @{ P = 'igfx|IntelGraphics|Intel.*Graphics|hkcmd|persistence'; R = 'Keep'; N = 'Intel graphics driver helper' }
    @{ P = 'Wacom|XP-Pen|Huion|OpenTabletDriver'; R = 'Keep'; N = 'Drawing tablet driver' }
    @{ P = 'Bluetooth|BTTray'; R = 'Keep'; N = 'Bluetooth helper' }
    @{ P = 'ctfmon|\bIME\b|TextInput'; R = 'Keep'; N = 'Keyboard / language input' }
    # ---- YOUR CHOICE ----
    @{ P = 'FACEIT'; R = 'Choice'; N = 'FACEIT anti-cheat - only needed when you play on FACEIT' }
    @{ P = 'AMDNoiseSuppression'; R = 'Disable'; N = 'AMD mic noise suppression - only needed if you use it' }
    @{ P = 'AMD.*(User Experience|UEP)|AUEP'; R = 'Disable'; N = 'AMD telemetry' }
    @{ P = 'RadeonSoftware|AMD Software|cncmd'; R = 'Choice'; N = 'AMD Radeon Software - needed for its overlay/hotkeys/Instant Replay' }
    @{ P = 'NVIDIA Broadcast'; R = 'Choice'; N = 'Needed if you use NVIDIA mic/camera effects' }
    @{ P = 'NvBackend|GeForce Experience|NVIDIA App|NvTmRep|ShadowPlay|nvcontainer'; R = 'Choice'; N = 'NVIDIA app - only needed for the overlay, recording or driver popups' }
    @{ P = 'Logi ?Options|LogiOptions|Logitech Options'; R = 'Choice'; N = 'Needed for custom mouse/keyboard buttons' }
    @{ P = 'LGHUB|G HUB|iCUE|Corsair|Razer|Synapse|SteelSeries|Armoury ?Crate|\bASUS\b|MSI Center|Dragon Center|Mystic Light|OpenRGB|SignalRGB|Alienware|NGENUITY|Wooting|Roccat|Turtle Beach|Glorious'; R = 'Choice'; N = 'Peripheral / RGB software - keep if you need your RGB, macros or DPI settings' }
    @{ P = 'Afterburner|RivaTuner|RTSS|Precision X|ThrottleStop|FanControl|Fan Control'; R = 'Choice'; N = 'Overclock / fan tool - keep if it applies your fan curve or overclock' }
    @{ P = 'Wallpaper ?Engine|wallpaper_engine|wallpaper32|wallpaper64|Lively'; R = 'Choice'; N = 'Animated wallpaper - keep if you want it on at boot' }
    @{ P = 'KeePass|Bitwarden|1Password|LastPass|Dashlane|NordPass|Proton Pass'; R = 'Choice'; N = 'Password manager' }
    @{ P = 'NordVPN|ExpressVPN|ProtonVPN|Surfshark|Mullvad|OpenVPN|WireGuard|CyberGhost|Windscribe|\bPIA\b|Private Internet Access|Tailscale|ZeroTier|Hamachi|AnyConnect|GlobalProtect|FortiClient'; R = 'Choice'; N = 'VPN - keep if you want it to connect automatically' }
    @{ P = 'Dropbox|Google ?Drive|GoogleDriveFS|iCloud|MEGAsync|pCloud|Box Sync|Sync\.com'; R = 'Choice'; N = 'Cloud sync - your files will not sync until you open it' }
    @{ P = 'OneDrive'; R = 'Choice'; N = 'OneDrive - your files will not sync until you open it' }
    @{ P = 'Greenshot|ShareX|Lightshot|Flameshot|Snagit|PowerToys|AutoHotkey|\bf\.?lux\b|DisplayFusion|TranslucentTB|RoundedTB|Rainmeter|EarTrumpet|voidtools|Everything\.exe|Flow ?Launcher|Rectangle'; R = 'Choice'; N = 'Utility you probably installed on purpose' }
    @{ P = 'Parsec|AnyDesk|TeamViewer|RustDesk|Chrome Remote|Sunshine'; R = 'Choice'; N = 'Remote access - keep only if you connect to this PC remotely' }
    @{ P = 'Docker|WSL|VirtualBox|VMware'; R = 'Choice'; N = 'Developer tool - keep if you need it running all the time' }
    @{ P = '\\HP\\|HP Inc|Hewlett|HPSA|HP Support|\bDell\b|SupportAssist|Lenovo|Vantage|\bAcer\b|Care Center|MyASUS|Samsung'; R = 'Choice'; N = 'PC maker utility - usually safe to turn off, but some control battery/fan modes' }
    @{ P = 'GamingServices'; R = 'Choice'; N = 'Needed for Game Pass / Xbox app games' }
    # ---- SAFE TO DISABLE ----
    @{ P = 'Discord'; R = 'Disable'; N = 'Opens Discord at boot - you can still open it yourself' }
    @{ P = 'Steam'; R = 'Disable'; N = 'Steam launcher - open it when you want to play' }
    @{ P = 'EpicGames|Epic Games'; R = 'Disable'; N = 'Epic Games launcher - open it when you want to play' }
    @{ P = 'Battle\.net|Blizzard'; R = 'Disable'; N = 'Battle.net launcher' }
    @{ P = 'EADesktop|EA app|\\Origin\\|Origin\.exe'; R = 'Disable'; N = 'EA app launcher' }
    @{ P = 'Ubisoft|Uplay|upc\.exe'; R = 'Disable'; N = 'Ubisoft Connect launcher' }
    @{ P = 'RiotClient|Riot Client'; R = 'Disable'; N = 'Riot Client launcher (not the anti-cheat)' }
    @{ P = 'GOG ?Galaxy'; R = 'Disable'; N = 'GOG Galaxy launcher' }
    @{ P = 'Rockstar'; R = 'Disable'; N = 'Rockstar launcher' }
    @{ P = 'Overwolf|CurseForge|Medal\.exe|Medal\.tv|\\Medal\\|Outplayed|Porofessor|Blitz|Mobalytics|U\.GG'; R = 'Disable'; N = 'Game overlay / companion app' }
    @{ P = 'Spotify'; R = 'Disable'; N = 'Opens Spotify at boot' }
    @{ P = 'Teams|ms-teams|MSTeams'; R = 'Disable'; N = 'Teams - keep only if you need it open for work/school' }
    @{ P = 'Skype'; R = 'Disable'; N = 'Skype' }
    @{ P = 'Zoom\.exe|\\Zoom\\|Zoom Video'; R = 'Disable'; N = 'Zoom - opens when you join a meeting anyway' }
    @{ P = 'Slack'; R = 'Disable'; N = 'Slack - keep if you need work notifications' }
    @{ P = 'WhatsApp|Telegram|\bSignal\b|Messenger|Viber'; R = 'Disable'; N = 'Chat app - opens at boot' }
    @{ P = 'MicrosoftEdgeAutoLaunch|msedge\.exe'; R = 'Disable'; N = 'Edge pre-loading itself in the background' }
    @{ P = 'GoogleChromeAutoLaunch|chrome\.exe|\bBrave\b|brave\.exe|\bOpera\b|opera\.exe|Vivaldi|Firefox'; R = 'Disable'; N = 'Browser auto-launch' }
    @{ P = 'Copilot'; R = 'Disable'; N = 'Copilot app' }
    @{ P = 'YourPhone|PhoneExperienceHost|Phone Link'; R = 'Disable'; N = 'Phone Link - opens when you need it' }
    @{ P = 'Cortana'; R = 'Disable'; N = 'Cortana' }
    @{ P = 'Xbox|GameBar'; R = 'Disable'; N = 'Xbox background helper' }
    @{ P = 'Adobe|Acrobat|CCXProcess|CoreSync|Creative Cloud|AdobeGC'; R = 'Disable'; N = 'Adobe background helper' }
    @{ P = 'iTunesHelper|iTunes|APSDaemon'; R = 'Disable'; N = 'iTunes helper' }
    @{ P = 'jusched|Java Update|Java Auto Updater'; R = 'Disable'; N = 'Java updater' }
    @{ P = 'CCleaner|Driver ?Booster|IObit|Advanced SystemCare|Restoro|Reimage|PC ?Cleaner|Wise Care|Glary'; R = 'Disable'; N = 'Cleaner/booster software - not needed' }
    @{ P = 'uTorrent|BitTorrent|qBittorrent|Deluge'; R = 'Disable'; N = 'Torrent client' }
    @{ P = 'Grammarly'; R = 'Disable'; N = 'Grammarly desktop' }
    @{ P = 'Cisco Webex|Webex'; R = 'Disable'; N = 'Webex - opens when you join a meeting' }
    @{ P = 'Update|Updater'; R = 'Disable'; N = 'Background updater - the app still updates when you open it' }
)

function Get-RecLabel {
    param([string]$Rec)
    switch ($Rec) { 'Disable' { 'SAFE TO DISABLE' } 'Keep' { 'KEEP' } default { 'YOUR CHOICE' } }
}
function Get-RecColor {
    param([string]$Rec)
    switch ($Rec) { 'Disable' { 'Green' } 'Keep' { 'Red' } default { 'Yellow' } }
}

function Set-Recommendation {
    param($Item)
    if ($Item.Missing) {
        $Item.Rec = 'Disable'
        $Item.Note = 'Points to a file that no longer exists (left over from an uninstalled app)'
        return
    }
    $text = '{0} {1} {2} {3}' -f $Item.Name, $Item.Command, $Item.Publisher, $Item.Description
    foreach ($k in $Script:KnownApps) {
        if ($text -match $k.P) { $Item.Rec = $k.R; $Item.Note = $k.N; return }
    }
    if ($Item.Publisher -match 'Microsoft') {
        $Item.Rec = 'Choice'; $Item.Note = 'Microsoft component - only turn off if you know what it does'
        return
    }
    $Item.Rec = 'Choice'
    $Item.Note = "Not in our list - turn it off if you don't need it running all the time"
}

function Get-ProcessMap {
    $map = @{}
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        $path = $null
        try { $path = $p.Path } catch {}
        if ($path) {
            $key = $path.ToLower()
            if (-not $map.ContainsKey($key)) { $map[$key] = New-Object System.Collections.Generic.List[object] }
            $map[$key].Add($p)
        }
    }
    return $map
}

function Get-ApprovedEnabled {
    param([string]$ApprovedKey, [string]$ValueName)
    $v = Get-RegValue $ApprovedKey $ValueName
    if ($v -is [byte[]] -and $v.Length -gt 0) { return (($v[0] -band 1) -eq 0) }
    return $true
}

# Same mechanism Task Manager's Startup tab uses - nothing is deleted
function Set-ApprovedState {
    param([string]$ApprovedKey, [string]$ValueName, [bool]$Enabled)
    if ($Enabled) {
        $bytes = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    } else {
        $bytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([long](Get-Date).ToFileTime()))
    }
    if (-not (Test-Path -LiteralPath $ApprovedKey)) { New-Item -Path $ApprovedKey -Force -ErrorAction Stop | Out-Null }
    New-ItemProperty -LiteralPath $ApprovedKey -Name $ValueName -Value $bytes -PropertyType Binary -Force -ErrorAction Stop | Out-Null
}

function New-StartupItem {
    param(
        [string]$Type, [string]$Name, [string]$Command, [string]$Exe = '',
        [bool]$Enabled = $true, [hashtable]$ProcMap = @{}, [hashtable]$Extra = @{},
        [object[]]$Processes = $null, [string]$Publisher = ''
    )
    if (-not $Exe) { $Exe = Get-ExeFromCommand $Command }
    $info = Get-FileInfo $Exe
    if ($null -eq $Processes) {
        $Processes = @()
        if ($Exe -and $ProcMap.ContainsKey($Exe.ToLower())) { $Processes = @($ProcMap[$Exe.ToLower()]) }
    }
    $mem = 0
    if ($Processes.Count -gt 0) { $mem = [math]::Round((($Processes | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB) }
    $missing = $false
    if ($Type -ne 'Store' -and $Exe -match '^[A-Za-z]:\\') { $missing = -not (Test-FileExists $Exe) }
    $typeLabel = switch ($Type) { 'Run' { 'Startup' } 'Folder' { 'Startup' } 'Store' { 'Store app' } 'Task' { 'Task' } 'Service' { 'Service' } }
    $pub = if ($Publisher) { $Publisher } else { $info.Company }

    $obj = [pscustomobject]@{
        Key = ''; Type = $Type; TypeLabel = $typeLabel; Name = $Name; Command = $Command; Exe = $Exe
        Publisher = $pub; Description = $info.Description; Enabled = $Enabled
        Processes = $Processes; Running = ($Processes.Count -gt 0); MemMB = $mem; Missing = $missing
        Rec = ''; Note = ''; Scope = ''
        ApprovedKey = $null; ValueName = $null; Location = $null
        TaskPath = $null; TaskName = $null; ServiceName = $null; PrevStart = $null
    }
    foreach ($k in $Extra.Keys) { $obj.$k = $Extra[$k] }
    $obj.Key = '{0}|{1}|{2}|{3}|{4}|{5}' -f $obj.Type, $obj.ApprovedKey, $obj.ValueName, $obj.Location, $obj.TaskName, $obj.ServiceName
    Set-Recommendation $obj
    return $obj
}

function Get-StartupItems {
    $procMap = Get-ProcessMap
    $items = New-Object System.Collections.Generic.List[object]

    # 1) Registry "Run" keys
    try {
    $runSources = @(
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = "$($Script:ApprovedHKCU)\Run";   Scope = 'This user' }
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "$($Script:ApprovedHKLM)\Run";   Scope = 'All users' }
        @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "$($Script:ApprovedHKLM)\Run32"; Scope = 'All users' }
    )
    foreach ($src in $runSources) {
        $key = Get-Item -LiteralPath $src.Key -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($valueName in $key.GetValueNames()) {
            if ([string]::IsNullOrEmpty($valueName)) { continue }
            $cmd = [string]$key.GetValue($valueName)
            $enabled = Get-ApprovedEnabled $src.Approved $valueName
            $items.Add((New-StartupItem -Type 'Run' -Name $valueName -Command $cmd -Enabled $enabled -ProcMap $procMap `
                -Extra @{ ApprovedKey = $src.Approved; ValueName = $valueName; Location = $src.Key; Scope = $src.Scope }))
        }
    }

    } catch { Write-Log "SCAN FAILED (Run keys): $($_.Exception.Message)" }

    # 2) Startup folders
    try {
    $folders = @(
        @{ Path = [Environment]::GetFolderPath('Startup');       Approved = "$($Script:ApprovedHKCU)\StartupFolder"; Scope = 'This user' }
        @{ Path = [Environment]::GetFolderPath('CommonStartup'); Approved = "$($Script:ApprovedHKLM)\StartupFolder"; Scope = 'All users' }
    )
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch {}
    foreach ($f in $folders) {
        if (-not $f.Path -or -not (Test-Path -LiteralPath $f.Path)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $f.Path -File -Force -ErrorAction SilentlyContinue)) {
            if ($file.Name -ieq 'desktop.ini') { continue }
            $exe = $file.FullName; $cmd = $file.FullName
            if ($file.Extension -ieq '.lnk' -and $shell) {
                try {
                    $lnk = $shell.CreateShortcut($file.FullName)
                    if ($lnk.TargetPath) { $exe = $lnk.TargetPath; $cmd = ('"{0}" {1}' -f $lnk.TargetPath, $lnk.Arguments).Trim() }
                } catch {}
            }
            $enabled = Get-ApprovedEnabled $f.Approved $file.Name
            $items.Add((New-StartupItem -Type 'Folder' -Name $file.BaseName -Command $cmd -Exe $exe -Enabled $enabled -ProcMap $procMap `
                -Extra @{ ApprovedKey = $f.Approved; ValueName = $file.Name; Location = $file.FullName; Scope = $f.Scope }))
        }
    }

    } catch { Write-Log "SCAN FAILED (Startup folders): $($_.Exception.Message)" }

    # 3) Microsoft Store app startup tasks
    try {
    $appRoot = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    if (Test-Path -LiteralPath $appRoot) {
        $appxByFamily = @{}
        foreach ($p in $Script:Sys.Appx) {
            if ($p.PackageFamilyName -and -not $appxByFamily.ContainsKey($p.PackageFamilyName)) { $appxByFamily[$p.PackageFamilyName] = $p }
        }
        foreach ($pkgKey in @(Get-ChildItem -LiteralPath $appRoot -ErrorAction SilentlyContinue)) {
            foreach ($taskKey in @(Get-ChildItem -LiteralPath $pkgKey.PSPath -ErrorAction SilentlyContinue)) {
                $state = $taskKey.GetValue('State', $null)
                if ($null -eq $state) { continue }
                $state = [int]$state
                if (@(1, 2) -notcontains $state) { continue }    # 1 = turned off by user, 2 = on
                $family = $pkgKey.PSChildName
                $friendly = (($family -split '_')[0] -split '\.')[-1]
                $pkg = $appxByFamily[$family]
                $procs = @(); $pub = ''; $exe = ''
                if ($pkg) {
                    if ($pkg.InstallLocation) {
                        $exe = [string]$pkg.InstallLocation
                        $loc = $exe.ToLower().TrimEnd('\') + '\'
                        foreach ($k in $procMap.Keys) { if ($k.StartsWith($loc)) { $procs += $procMap[$k] } }
                    }
                    if ($pkg.Publisher -match 'CN=([^,]+)') { $pub = $Matches[1].Trim('"') }
                }
                $items.Add((New-StartupItem -Type 'Store' -Name $friendly -Command $family -Exe $exe -Enabled ($state -eq 2) `
                    -ProcMap $procMap -Processes $procs -Publisher $pub `
                    -Extra @{ Location = $taskKey.PSPath; ValueName = $taskKey.PSChildName; Scope = 'Store app' }))
            }
        }
    }

    } catch { Write-Log "SCAN FAILED (Store apps): $($_.Exception.Message)" }

    # 4) Third-party scheduled tasks that run at logon/boot, or are updaters
    try {
    foreach ($t in @(Get-AllTasks)) {
        if ($t.TaskPath -like '\Microsoft\*') { continue }
        $trig = @($t.Triggers | Where-Object { $_ } | ForEach-Object { $_.CimClass.CimClassName })
        $atLogon = [bool]($trig -match 'Logon|Boot')
        $updater = $t.TaskName -match 'update'
        if (-not ($atLogon -or $updater)) { continue }
        $act = @($t.Actions | Where-Object { $_.Execute }) | Select-Object -First 1
        if ($act) { $cmd = ('"{0}" {1}' -f ([string]$act.Execute).Trim('"'), $act.Arguments).Trim() } else { $cmd = '' }
        $display = $t.TaskName -replace '-S-1-5-[\d-]+$', '' -replace '\{[0-9A-Fa-f-]{36}\}$', ''
        $scope = if ($atLogon) { 'Runs at logon/boot' } else { 'Updater task' }
        $items.Add((New-StartupItem -Type 'Task' -Name $display -Command $cmd -Enabled ($t.State -ne 'Disabled') -ProcMap $procMap `
            -Extra @{ TaskPath = $t.TaskPath; TaskName = $t.TaskName; Location = "$($t.TaskPath)$($t.TaskName)"; Scope = $scope }))
    }

    } catch { Write-Log "SCAN FAILED (Scheduled tasks): $($_.Exception.Message)" }

    # 5) Third-party services that start automatically
    try {
    foreach ($svc in @(Get-CimSafe 'Win32_Service' "StartMode='Auto'")) {
        $exe = Get-ExeFromCommand $svc.PathName
        if (-not $exe -or $exe -like "$env:windir\*" -or $exe -like '*\Windows Defender*') { continue }
        $info = Get-FileInfo $exe
        if ($info.Company -match 'Microsoft' -and $svc.Name -ne 'edgeupdate') { continue }
        $prev = if ($svc.DelayedAutoStart) { 'DelayedAuto' } else { 'Auto' }
        $items.Add((New-StartupItem -Type 'Service' -Name $svc.DisplayName -Command $svc.PathName -Exe $exe -Enabled $true -ProcMap $procMap `
            -Extra @{ ServiceName = $svc.Name; PrevStart = $prev; Location = $svc.Name; Scope = 'Windows service (will be set to Manual)' }))
    }
    } catch { Write-Log "SCAN FAILED (Services): $($_.Exception.Message)" }

    return $items
}

# ---------------- backup file (for Undo) ----------------
function Get-Backup {
    if (-not (Test-Path -LiteralPath $Script:BackupFile)) { return @() }
    try {
        $data = Get-Content -LiteralPath $Script:BackupFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return @($data)
    } catch { return @() }
}

function Save-Backup {
    param($Entries)
    $arr = @($Entries)
    if ($arr.Count -eq 0) { Remove-Item -LiteralPath $Script:BackupFile -Force -ErrorAction SilentlyContinue; return }
    ConvertTo-Json -InputObject $arr -Depth 4 | Set-Content -LiteralPath $Script:BackupFile -Encoding UTF8
}

function Add-Backup {
    param($Item)
    $list = @(Get-Backup | Where-Object { $_.Key -ne $Item.Key })
    $list += [pscustomobject]@{
        Key = $Item.Key; Type = $Item.Type; Name = $Item.Name; ApprovedKey = $Item.ApprovedKey; ValueName = $Item.ValueName
        Location = $Item.Location; TaskPath = $Item.TaskPath; TaskName = $Item.TaskName; ServiceName = $Item.ServiceName
        PrevStart = $Item.PrevStart; Date = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    }
    Save-Backup $list
}

function Remove-Backup {
    param([string]$Key)
    Save-Backup @(Get-Backup | Where-Object { $_.Key -ne $Key })
}

# ---------------- turn items off / on ----------------
function Get-StartupMethod {
    param($Item, [bool]$On)
    switch ($Item.Type) {
        'Service' { if ($On) { return 'startup type back to Automatic' } else { return 'startup type Automatic -> Manual' } }
        'Task'    { if ($On) { return 'scheduled task enabled' } else { return 'scheduled task disabled' } }
        'Store'   { return 'Store app startup setting' }
        default   { if ($On) { return 'marked Enabled, like Task Manager' } else { return 'marked Disabled, like Task Manager - nothing deleted' } }
    }
}

function Disable-StartupItem {
    param($Item)
    if ($Script:Preview) {
        Add-PreviewLine 'would turn off' ("{0} ({1}: {2})" -f $Item.Name, $Item.TypeLabel, (Get-StartupMethod $Item $false))
        return $false
    }
    try {
        switch ($Item.Type) {
            'Run'     { Set-ApprovedState $Item.ApprovedKey $Item.ValueName $false }
            'Folder'  { Set-ApprovedState $Item.ApprovedKey $Item.ValueName $false }
            'Store'   { Set-ItemProperty -LiteralPath $Item.Location -Name 'State' -Value 1 -Type DWord -ErrorAction Stop }
            'Task'    { Disable-ScheduledTask -TaskPath $Item.TaskPath -TaskName $Item.TaskName -ErrorAction Stop | Out-Null }
            'Service' { Set-Service -Name $Item.ServiceName -StartupType Manual -ErrorAction Stop }
        }
        Add-Backup $Item
        Write-Log "STARTUP OFF [$($Item.Type)] $($Item.Name) | $($Item.Command)"
        $Script:StartupChanges++
        return $true
    } catch {
        Warn "Could not turn off $($Item.Name): $($_.Exception.Message)"
        return $false
    }
}

function Enable-StartupItem {
    param($Item)
    if ($Script:Preview) {
        Add-PreviewLine 'would turn on' ("{0} ({1}: {2})" -f $Item.Name, $Item.Type, (Get-StartupMethod $Item $true))
        return $false
    }
    try {
        switch ($Item.Type) {
            'Run'     { Set-ApprovedState $Item.ApprovedKey $Item.ValueName $true }
            'Folder'  { Set-ApprovedState $Item.ApprovedKey $Item.ValueName $true }
            'Store'   { Set-ItemProperty -LiteralPath $Item.Location -Name 'State' -Value 2 -Type DWord -ErrorAction Stop }
            'Task'    { Enable-ScheduledTask -TaskPath $Item.TaskPath -TaskName $Item.TaskName -ErrorAction Stop | Out-Null }
            'Service' {
                if ($Item.PrevStart -eq 'DelayedAuto') { sc.exe config $Item.ServiceName start= delayed-auto | Out-Null }
                else { Set-Service -Name $Item.ServiceName -StartupType Automatic -ErrorAction Stop }
            }
        }
        Remove-Backup $Item.Key
        Write-Log "STARTUP ON [$($Item.Type)] $($Item.Name)"
        $Script:StartupChanges++
        return $true
    } catch {
        Warn "Could not turn on $($Item.Name): $($_.Exception.Message)"
        return $false
    }
}

function Stop-ItemProcesses {
    param($Item)
    if ($Script:Preview) { Add-PreviewLine 'would close' $Item.Name; return }
    if ($Item.Type -eq 'Service') {
        Stop-Service -Name $Item.ServiceName -Force -ErrorAction SilentlyContinue
        return
    }
    foreach ($p in @($Item.Processes)) {
        if (-not $p -or $Script:ProtectedProcs -contains $p.ProcessName) { continue }
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
    }
}

# ---------------- display ----------------
function Get-ConsoleWidth {
    try { $w = $Host.UI.RawUI.WindowSize.Width; if ($w -gt 20) { return $w } } catch {}
    return 120
}

function Show-StartupList {
    param($Items)
    # Fit the table to the window: drop columns on narrow windows
    $w = Get-ConsoleWidth
    $showType = $w -ge 85
    $showPub  = $w -ge 110
    $fixed = 2 + 3 + 2 + 9 + 17
    if ($showType) { $fixed += 11 }
    if ($showPub)  { $fixed += 20 }
    $nameW = [Math]::Max(14, [Math]::Min(32, $w - $fixed - 2))
    $pubW  = [Math]::Max(10, $w - $fixed - $nameW - 2 + 20)

    Write-Host ""
    $header = ("  {0,3}  {1,-8} {2,-16} " -f '#', 'NOW', 'ADVICE') + ("{0,-$nameW} " -f 'NAME')
    if ($showType) { $header += "{0,-10} " -f 'TYPE' }
    if ($showPub)  { $header += 'PUBLISHER' }
    Write-Host $header -ForegroundColor DarkGray
    $i = 0
    foreach ($it in $Items) {
        $i++
        $now = if ($it.Running) { "{0}MB" -f $it.MemMB } else { '-' }
        Write-Host ("  {0,3}  " -f $i) -NoNewline
        Write-Host ("{0,-8} " -f $now) -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-16} " -f (Get-RecLabel $it.Rec)) -ForegroundColor (Get-RecColor $it.Rec) -NoNewline
        $line = "{0,-$nameW} " -f (Get-Short $it.Name $nameW)
        if ($showType) { $line += "{0,-10} " -f $it.TypeLabel }
        if ($showPub) {
            Write-Host $line -NoNewline
            Write-Host (Get-Short $it.Publisher $pubW) -ForegroundColor DarkGray
        } else {
            Write-Host $line
        }
    }
    Write-Host ""
    Write-Host "  NOW = RAM it's using right now if it's running." -ForegroundColor DarkGray
}

function Show-StartupItemDetail {
    param($It, [int]$N, [int]$Total)
    Write-Host ""
    Write-Host ("  [{0}/{1}] " -f $N, $Total) -ForegroundColor DarkGray -NoNewline
    Write-Host $It.Name -ForegroundColor White -NoNewline
    Write-Host ("   ({0} - {1})" -f $It.TypeLabel, $It.Scope) -ForegroundColor DarkGray
    if ($It.Running)   { Write-Host ("         Running now, using {0} MB of RAM" -f $It.MemMB) -ForegroundColor Cyan }
    if ($It.Publisher) { Write-Host "         Publisher : $($It.Publisher)" -ForegroundColor Gray }
    if ($It.Command)   { Write-Host "         Command   : $(Get-Short $It.Command 95)" -ForegroundColor DarkGray }
    Write-Host "         Advice    : " -ForegroundColor Gray -NoNewline
    Write-Host (Get-RecLabel $It.Rec) -ForegroundColor (Get-RecColor $It.Rec) -NoNewline
    Write-Host " - $($It.Note)" -ForegroundColor Gray
}

function Invoke-BatchDisable {
    param($Items)
    if (-not $Items -or @($Items).Count -eq 0) { Warn "Nothing selected."; return }
    Write-Host ""
    foreach ($it in $Items) {
        Write-Host "     - $($it.Name)" -NoNewline
        Write-Host "  ($(Get-RecLabel $it.Rec))" -ForegroundColor (Get-RecColor $it.Rec)
    }
    $keep = @($Items | Where-Object { $_.Rec -eq 'Keep' })
    $note = if ($keep.Count) { "$($keep.Count) of these are marked KEEP - turning them off may break drivers/security." } else { '' }
    if (-not (Ask "Turn off auto-start for these $(@($Items).Count) item(s)?" '' $note)) { return }

    $ok = @()
    foreach ($it in $Items) {
        if (Disable-StartupItem $it) { Done "$($it.Name) won't start automatically anymore."; $ok += $it }
    }
    $running = @($ok | Where-Object { $_.Running })
    if ($running.Count -gt 0) {
        $mb = ($running | Measure-Object -Property MemMB -Sum).Sum
        if (Ask "$($running.Count) of them are running right now (~$mb MB of RAM). Close them now too?" '' 'Save your work in those apps first.') {
            foreach ($it in $running) { Stop-ItemProcesses $it }
            Done "Closed. That RAM is free now."
        }
    }
}

function Invoke-StartupOneByOne {
    param($Items)
    $n = 0
    $total = @($Items).Count
    foreach ($it in $Items) {
        $n++
        Show-StartupItemDetail $it $n $total
        $ans = Read-Choice "Turn off auto-start for this? [Y = yes, N = no, Q = stop asking]:" @('Y', 'N', 'Q')
        if ($ans -eq 'Q') { break }
        if ($ans -eq 'N') { Skip $it.Name; continue }
        if (Disable-StartupItem $it) {
            Done "$($it.Name) won't start automatically anymore."
            if ($it.Running -and (Ask "It's running right now ($($it.MemMB) MB). Close it now too?")) {
                Stop-ItemProcesses $it
                Done "Closed $($it.Name)."
            }
        }
    }
}

function Show-HeavyApps {
    Section "What's using your RAM right now"
    $s = $Script:Sys
    $os = Get-CimSafe 'Win32_OperatingSystem' | Select-Object -First 1
    if ($os -and $os.TotalVisibleMemorySize) {
        $usedGB = [math]::Round(([double]$os.TotalVisibleMemorySize - [double]$os.FreePhysicalMemory) / 1MB, 1)
        Write-Host "   RAM in use: $usedGB GB of $($s.RamGB) GB" -ForegroundColor White
    }

    $groups = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $Script:ProtectedProcs -notcontains $_.ProcessName -and $_.Id -ne $PID } |
        Group-Object -Property ProcessName | ForEach-Object {
            $g = $_
            $path = $null
            foreach ($p in $g.Group) { try { if ($p.Path) { $path = $p.Path; break } } catch {} }
            $hasWindow = [bool]($g.Group | Where-Object { $_.MainWindowHandle -ne 0 })
            [pscustomobject]@{
                Name = $g.Name; Count = $g.Count; Path = $path; HasWindow = $hasWindow
                MemMB = [math]::Round((($g.Group | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB)
            }
        } | Where-Object { $_.Path -and $_.Path -notlike "$env:windir\*" -and $_.MemMB -ge 50 } |
        Sort-Object -Property MemMB -Descending | Select-Object -First 15)

    if ($groups.Count -eq 0) { Info "Nothing heavy running besides Windows itself."; return }
    Write-Host ""
    $showPub = (Get-ConsoleWidth) -ge 100
    Write-Host ("  {0,3}  {1,-8} {2,-12} {3,-30} {4}" -f '#', 'RAM', 'KIND', 'APP', $(if ($showPub) { 'PUBLISHER' } else { '' })) -ForegroundColor DarkGray
    $i = 0
    foreach ($g in $groups) {
        $i++
        $kind = if ($g.HasWindow) { 'open window' } else { 'background' }
        $pub = if ($showPub) { (Get-FileInfo $g.Path).Company } else { '' }
        $name = if ($g.Count -gt 1) { "$($g.Name) (x$($g.Count))" } else { $g.Name }
        Write-Host ("  {0,3}  " -f $i) -NoNewline
        Write-Host ("{0,-8} " -f ("{0}MB" -f $g.MemMB)) -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-12} " -f $kind) -ForegroundColor $(if ($g.HasWindow) { 'Gray' } else { 'Yellow' }) -NoNewline
        if ($showPub) {
            Write-Host ("{0,-30} " -f (Get-Short $name 30)) -NoNewline
            Write-Host (Get-Short $pub 28) -ForegroundColor DarkGray
        } else {
            Write-Host (Get-Short $name 30)
        }
    }
    Write-Host ""
    $txt = Read-Host "  Type numbers to close now (e.g. 1,3), or just press Enter to skip"
    $sel = @(Parse-Selection $txt $groups.Count)
    if ($sel.Count -eq 0) { return }
    $chosen = @($sel | ForEach-Object { $groups[$_ - 1] })
    if (-not (Ask "Close $(($chosen | ForEach-Object { $_.Name }) -join ', ')?" 'CAUTION' 'Unsaved work in those apps will be lost.')) { return }
    foreach ($g in $chosen) {
        if ($Script:Preview) { Add-PreviewLine 'would close' "$($g.Name) (~$($g.MemMB) MB)"; continue }
        Stop-Process -Name $g.Name -Force -ErrorAction SilentlyContinue
        Done "Closed $($g.Name) (freed ~$($g.MemMB) MB)"
    }
}

function Invoke-StartupScanner {
    while ($true) {
        Section "Startup & Background Apps Scanner"
        Write-Host "  Scanning startup apps, Store apps, scheduled tasks and services..." -ForegroundColor Gray
        $Script:LastScan = @(Get-StartupItems)
        $order = @{ 'Disable' = 0; 'Choice' = 1; 'Keep' = 2 }
        $enabled  = @($Script:LastScan | Where-Object { $_.Enabled } |
                      Sort-Object -Property @{ Expression = { $order[$_.Rec] } }, @{ Expression = { -not $_.Running } }, Name)
        $disabled = @($Script:LastScan | Where-Object { -not $_.Enabled } | Sort-Object Name)
        $safe     = @($enabled | Where-Object { $_.Rec -eq 'Disable' })
        $runMB    = ($enabled | Where-Object { $_.Running } | Measure-Object -Property MemMB -Sum).Sum
        if (-not $runMB) { $runMB = 0 }

        if ($enabled.Count -eq 0) {
            Done "Nothing extra starts with Windows. Nice and clean!"
        } else {
            Show-StartupList $enabled
            Write-Host ("  {0} item(s) start automatically, using ~{1} MB right now. {2} are safe to turn off." -f $enabled.Count, $runMB, $safe.Count) -ForegroundColor White
        }
        if ($disabled.Count) { Write-Host "  $($disabled.Count) item(s) are already turned off." -ForegroundColor DarkGray }

        Write-Host ""
        Write-Host "   [1] Go through them one by one (Y/N for each)"
        Write-Host "   [2] Type the numbers to turn off (e.g. 1,3,5-7)"
        Write-Host "   [3] Turn off everything marked SAFE TO DISABLE ($($safe.Count))"
        Write-Host "   [4] See what's using RAM right now / close apps"
        Write-Host "   [5] Turn something back on ($($disabled.Count) turned off)"
        Write-Host "   [0] Back"
        $c = Read-Choice "Choose [0-5]:" @('0', '1', '2', '3', '4', '5')

        if ($c -eq '0') { return }
        if ($c -eq '1') {
            if ($enabled.Count) { Invoke-StartupOneByOne $enabled } else { Info "Nothing to go through." }
        }
        if ($c -eq '2') {
            $txt = Read-Host "  Numbers to turn off (e.g. 1,3,5-7)"
            $sel = @(Parse-Selection $txt $enabled.Count)
            Invoke-BatchDisable @($sel | ForEach-Object { $enabled[$_ - 1] })
        }
        if ($c -eq '3') { Invoke-BatchDisable $safe }
        if ($c -eq '4') { Show-HeavyApps }
        if ($c -eq '5') {
            if ($disabled.Count -eq 0) { Info "Nothing is turned off." }
            else {
                Write-Host ""
                $i = 0
                foreach ($d in $disabled) { $i++; Write-Host ("  {0,3}. {1}  ({2})" -f $i, $d.Name, $d.TypeLabel) }
                $txt = Read-Host "  Numbers to turn back on (e.g. 2,4), or Enter to cancel"
                foreach ($n in @(Parse-Selection $txt $disabled.Count)) {
                    $d = $disabled[$n - 1]
                    if (Enable-StartupItem $d) { Done "$($d.Name) will start with Windows again." }
                }
            }
        }
        Read-Host "`n  Press Enter to refresh the list" | Out-Null
    }
}

# ============================================================
# JUNK CLEANUP
# ============================================================
function Invoke-Cleanup {
    Section "Junk File Cleanup"
    Write-Host "  Measuring junk files..." -ForegroundColor Gray
    $targets = @(
        [pscustomobject]@{ Name = 'Your temp files'; Paths = @($env:TEMP) }
        [pscustomobject]@{ Name = 'Windows temp files'; Paths = @("$env:windir\Temp") }
        [pscustomobject]@{ Name = 'Windows Update download cache'; Paths = @("$env:windir\SoftwareDistribution\Download"); Services = @('wuauserv', 'bits') }
        [pscustomobject]@{ Name = 'Crash dumps & error reports'; Paths = @("$env:LOCALAPPDATA\CrashDumps", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue") }
        [pscustomobject]@{ Name = 'GPU shader caches'; Note = 'Games may stutter a little the first time while the cache rebuilds.'
                           Paths = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache",
                                     "$env:LOCALAPPDATA\AMD\DxCache", "$env:LOCALAPPDATA\AMD\DxcCache", "$env:LOCALAPPDATA\AMD\GLCache") }
    )
    if ($Script:Preview) {
        $Script:PreviewLog.Add("")
        $Script:PreviewLog.Add("== Junk file cleanup ==")
        foreach ($t in $targets) {
            $size = Get-FolderSize $t.Paths
            if ($size -ge 1MB) { Add-PreviewLine 'would offer to delete' "$($t.Name) - $(Format-Size $size) ($($t.Paths -join '; '))" }
        }
        Add-PreviewLine 'would offer' 'empty the Recycle Bin, clear the Delivery Optimization cache, flush DNS'
        Add-PreviewLine 'would offer' 'DISM component cleanup and SFC system file repair'
        Save-PreviewReport
        return
    }
    $freed = 0
    foreach ($t in $targets) {
        $size = Get-FolderSize $t.Paths
        if ($size -lt 1MB) { continue }
        if (Ask "Delete $($t.Name)? ($(Format-Size $size))" 'REC' $t.Note) {
            foreach ($svc in @($t.Services)) { if ($svc) { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } }
            Clear-Folder $t.Paths
            foreach ($svc in @($t.Services)) { if ($svc) { Start-Service -Name $svc -ErrorAction SilentlyContinue } }
            $after = Get-FolderSize $t.Paths
            $gain = [math]::Max(0, $size - $after)
            $freed += $gain
            Done "$($t.Name): freed $(Format-Size $gain) (files in use were skipped)"
        } else { Skip $t.Name }
    }

    # Recycle Bin
    $binSize = 0
    try {
        $bin = (New-Object -ComObject Shell.Application).NameSpace(10)
        foreach ($item in $bin.Items()) { $binSize += [double]$item.Size }
    } catch {}
    if ($binSize -ge 1MB -and (Ask "Empty the Recycle Bin? ($(Format-Size $binSize))")) {
        if ($Script:Has.RecycleBin) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
        else { foreach ($item in @($bin.Items())) { try { Remove-Item -LiteralPath $item.Path -Recurse -Force -ErrorAction SilentlyContinue } catch {} } }
        $freed += $binSize
        Done "Recycle Bin emptied."
    }

    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        if (Ask "Clear the Delivery Optimization cache? (old update files shared with other PCs)" 'REC') {
            Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue | Out-Null
            Done "Delivery Optimization cache cleared."
        }
    }

    if (Ask "Flush the DNS cache? (can fix websites not loading)" 'REC') {
        ipconfig /flushdns | Out-Null
        Done "DNS cache flushed."
    }

    if (Ask "Clean up old Windows Update files? (DISM component cleanup, 5-15 minutes)" 'CHOICE' "Frees space used by superseded updates. You can't uninstall those old updates after.") {
        Pink "     Running DISM, please wait..."
        Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup' -NoNewWindow -Wait
        Done "Component cleanup finished."
    }

    if (Ask "Scan and repair Windows system files? (SFC + DISM, 15-30 minutes)" 'CHOICE' "Only needed if Windows is crashing or acting weird.") {
        Pink "     Running DISM RestoreHealth, please wait..."
        Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/RestoreHealth' -NoNewWindow -Wait
        Pink "     Running SFC, please wait..."
        Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' -NoNewWindow -Wait
        Done "System file check finished."
    }

    Write-Host ""
    Done "Cleanup finished - freed about $(Format-Size $freed)."
    $Script:Applied.Add("Junk cleanup ($(Format-Size $freed) freed)")
}

# ============================================================
# UNDO MENU
# ============================================================
function Invoke-UndoTweaks {
    param($Records)
    $list = @($Records)
    [array]::Reverse($list)    # newest first
    $fails = 0
    foreach ($r in $list) {
        if ($Script:Preview) { Write-Host "     $($r.Title)" -ForegroundColor White }
        else { Pink "     Undoing: $($r.Title)..." }
        $f = Undo-TweakRecord $r
        $fails += $f
        if (-not $Script:Preview -and $f -eq 0) { Done "$($r.Title) undone." }
    }
    if ($Script:NeedsExplorerRestart) { Restart-Explorer }
    if (-not $Script:Preview) {
        if ($fails) { Warn "$fails change(s) couldn't be undone - see the log. System Restore can still roll everything back." }
        else { Info "Restart your PC so every setting goes back fully." }
    }
}

function Invoke-UndoMenu {
    while ($true) {
        Section "Undo / Restore"
        $journal = @(Get-TweakJournal)
        $backup  = @(Get-Backup)
        $ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\TextInputHost.exe'
        $layersCU = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
        $layersLM = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
        # Older versions changed these without saving the old value - offer a manual fix
        $touchBlocked = [bool](Get-RegValue $ifeo 'Debugger') -and -not ($journal | Where-Object { $_.Title -like 'Block touch keyboard*' })
        $termAdmin = $false
        foreach ($exe in (Get-TerminalExes)) {
            if ((Get-RegValue $layersCU $exe) -or (Get-RegValue $layersLM $exe)) { $termAdmin = $true }
        }
        if ($journal | Where-Object { $_.Title -eq 'Terminals always as admin' }) { $termAdmin = $false }

        if ($journal.Count) {
            Write-Host "   Tweaks applied by Lerxna Optimizer:" -ForegroundColor White
            $i = 0
            foreach ($r in $journal) {
                $i++
                $changes = @($r.Changes | Where-Object { $_ })
                $partial = if (@($changes | Where-Object { $_.Kind -eq 'Note' }).Count) { '  (part of it is permanent)' } else { '' }
                Write-Host ("   {0,3}. {1}  - {2} change(s), {3}" -f $i, $r.Title, $changes.Count, $r.Date) -NoNewline
                Write-Host $partial -ForegroundColor DarkYellow
            }
        } else {
            Info "No tweaks to undo (tweaks applied with v2.0 or older can only be rolled back with System Restore)."
        }
        Write-Host ""
        if ($backup.Count) {
            Write-Host "   Startup items turned off by Lerxna Optimizer:" -ForegroundColor White
            $i = 0
            foreach ($b in $backup) { $i++; Write-Host ("   {0,3}. {1}  ({2}, {3})" -f $i, $b.Name, $b.Type, $b.Date) }
        } else {
            Info "No startup items have been turned off by Lerxna Optimizer."
        }

        $valid = @('0', 'R')
        Write-Host ""
        if ($journal.Count) {
            Write-Host "   [T] Undo ALL tweaks"
            Write-Host "   [P] Pick which tweaks to undo"
            Write-Host "   [V] Show exactly what undoing would change (changes nothing)"
            $valid += 'T', 'P', 'V'
        }
        if ($backup.Count) {
            Write-Host "   [S] Turn ALL startup items back on"
            Write-Host "   [O] Pick which startup items to turn back on"
            $valid += 'S', 'O'
        }
        if ($touchBlocked) {
            Write-Host "   [K] Fix touch keyboard / emoji panel / clipboard history (remove TextInputHost block)"
            $valid += 'K'
        }
        if ($termAdmin) {
            Write-Host "   [A] Stop PowerShell / CMD / Terminal always running as admin"
            $valid += 'A'
        }
        Write-Host "   [R] Open System Restore (roll everything back to a restore point)"
        Write-Host "   [0] Back"
        $c = Read-Choice "Choose:" $valid

        switch ($c) {
            '0' { return }
            'T' {
                if (Ask "Undo all $($journal.Count) tweak(s)?") { Invoke-UndoTweaks $journal }
            }
            'P' {
                $txt = Read-Host "  Tweak numbers to undo (e.g. 1,3)"
                $sel = @(Parse-Selection $txt $journal.Count)
                if ($sel.Count) { Invoke-UndoTweaks @($sel | Sort-Object | ForEach-Object { $journal[$_ - 1] }) }
            }
            'V' {
                $wasPreview = $Script:Preview
                $Script:Preview = $true
                try {
                    Write-Host ""
                    Write-Host "   Undoing everything would:" -ForegroundColor White
                    Invoke-UndoTweaks $journal
                    $Script:PreviewLog.Clear()
                } finally { $Script:Preview = $wasPreview }
            }
            'S' { foreach ($b in $backup) { if (Enable-StartupItem $b) { Done "$($b.Name) turned back on." } } }
            'O' {
                $txt = Read-Host "  Startup item numbers to turn back on (e.g. 1,3)"
                foreach ($n in @(Parse-Selection $txt $backup.Count)) {
                    $b = $backup[$n - 1]
                    if (Enable-StartupItem $b) { Done "$($b.Name) turned back on." }
                }
            }
            'K' {
                Remove-Reg $ifeo 'Debugger'
                if (-not $Script:Preview) { Done "Touch keyboard, emoji panel and clipboard history will work again (sign out or restart)." }
            }
            'A' {
                foreach ($exe in (Get-TerminalExes)) {
                    Remove-Reg $layersCU $exe
                    Remove-Reg $layersLM $exe
                }
                if (-not $Script:Preview) { Done "Terminals will open normally again." }
            }
            'R' {
                if ($Script:Preview) { Add-PreviewLine 'would open' 'System Restore' }
                else { Start-Process 'rstrui.exe' -ErrorAction SilentlyContinue; Info "System Restore opened in a new window." }
            }
        }
    }
}

# ============================================================
# SUMMARY / EXIT
# ============================================================
function Complete-Run {
    if ($Script:NeedsExplorerRestart) { Restart-Explorer }
    Section "Summary"
    if ($Script:Preview) {
        Write-Host ("   PREVIEW MODE - nothing was changed. Previewed {0} option(s)." -f $Script:Previewed.Count) -ForegroundColor Cyan
        Save-PreviewReport
        Info "Turn preview off in the main menu (option 8) when you're ready to apply changes."
        $Script:SummaryShownAt = $Script:Applied.Count + $Script:StartupChanges
        return
    }
    Write-Host ("   Applied              : {0}" -f $Script:Applied.Count) -ForegroundColor Green
    foreach ($a in $Script:Applied) { Write-Host "     + $a" -ForegroundColor Green }
    Write-Host ("   Skipped              : {0}" -f $Script:Skipped.Count) -ForegroundColor DarkGray
    if ($Script:Failed.Count) {
        Write-Host ("   Failed               : {0}" -f $Script:Failed.Count) -ForegroundColor Yellow
        foreach ($f in $Script:Failed) { Write-Host "     ! $f" -ForegroundColor Yellow }
    }
    Write-Host ("   Startup changes      : {0}" -f $Script:StartupChanges) -ForegroundColor Cyan
    Write-Host ""
    Info "Log file    : $Script:LogFile"
    Info "Changed your mind? Run Lerxna Optimizer again > Undo / restore - every tweak can be undone on its own."
    $Script:SummaryShownAt = $Script:Applied.Count + $Script:StartupChanges

    if ($Script:Applied.Count -gt 0 -or $Script:NeedsReboot) {
        Write-Host ""
        Pink "  Restart your PC for all changes to take effect."
        if (Ask "Restart now?" '' 'Save your work in other apps first.') {
            Restart-Computer -Force
        }
    }
}

# ============================================================
# SELF-TEST (run by GitHub Actions on a real Windows machine)
#   -SelfTest              : scan + preview every tweak, change nothing
#   -SelfTest -RoundTrip   : also APPLY every tweak, UNDO it, and check
#                            that every setting is back to how it was
# Exit code 0 = passed, 1 = failed
# ============================================================
function Write-TestResult {
    param([bool]$Ok, [string]$Text)
    if ($Ok) { Write-Host "  [PASS] $Text" -ForegroundColor Green }
    else {
        Write-Host "  [FAIL] $Text" -ForegroundColor Red
        if ($env:GITHUB_ACTIONS) { Write-Host "::error::$Text" }
    }
}

function Invoke-SelfTest {
    $failures = 0
    $step = {
        param([string]$Name, [scriptblock]$Block)
        try { & $Block | Out-Null; Write-TestResult $true $Name; return 0 }
        catch {
            Write-TestResult $false ("{0}: {1} (line {2})" -f $Name, $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber)
            return 1
        }
    }
    Write-Host "== Lerxna Optimizer v$($Script:Version) self-test on $([Environment]::OSVersion.VersionString), PowerShell $($PSVersionTable.PSVersion) ==" -ForegroundColor White

    $failures += & $step 'PC scan'           { $Script:Sys = Get-SystemProfile; if (-not $Script:Sys.Build) { throw 'no Windows build detected' } }
    $failures += & $step 'Startup scan'      { $Script:LastScan = @(Get-StartupItems); Write-Host "         found $($Script:LastScan.Count) startup item(s)" }
    $failures += & $step 'PC report + health'{ Show-SystemReport }
    $failures += & $step 'Startup list'      { if ($Script:LastScan.Count) { Show-StartupList $Script:LastScan } }
    $failures += & $step 'Build tweak list'  { Initialize-Tweaks; if (@($Script:Tweaks).Count -lt 30) { throw "only $(@($Script:Tweaks).Count) tweaks" } }

    $visible = @($Script:Tweaks | Where-Object { $null -eq $_.Show -or $_.Show })
    Write-Host "         $($visible.Count) of $(@($Script:Tweaks).Count) tweaks apply to this machine"

    # 1) Preview every tweak - must not throw and must not change anything
    $journalBefore = Test-Path -LiteralPath $Script:JournalFile
    $Script:Preview = $true
    foreach ($t in $visible) {
        $failures += & $step "Preview: $($t.Title)" { & $t.Action | Out-Null }
    }
    $failures += & $step 'Preview: junk cleanup' { Invoke-Cleanup }
    $Script:Preview = $false
    $failures += & $step 'Preview changed nothing' {
        if ((Test-Path -LiteralPath $Script:JournalFile) -ne $journalBefore) { throw 'the undo journal was written during preview' }
    }

    if ($RoundTrip) {
        Write-Host ""
        Write-Host "== Round trip: apply every tweak, undo it, verify ==" -ForegroundColor White
        # Start with an empty journal so only this test's changes are in it
        if (Test-Path -LiteralPath $Script:JournalFile) { Move-Item -LiteralPath $Script:JournalFile -Destination "$($Script:JournalFile).before-selftest" -Force }

        foreach ($t in @($visible | Where-Object { -not $_.Interactive -and -not $_.NoRoundTrip })) {
            Invoke-Tweak $t
        }
        $journal = @(Get-TweakJournal)
        $changeCount = (@($journal | ForEach-Object { @($_.Changes | Where-Object { $_ }) }) | Measure-Object).Count
        Write-Host "         $($journal.Count) tweaks recorded $changeCount change(s)"
        $failures += & $step 'Tweaks recorded changes' { if ($changeCount -lt 20) { throw "only $changeCount changes were recorded" } }

        # Undo everything, newest first
        $undoFails = 0
        $list = @($journal); [array]::Reverse($list)
        foreach ($r in $list) { $undoFails += Undo-TweakRecord $r }
        $failures += & $step 'Undo ran without errors' { if ($undoFails) { throw "$undoFails change(s) failed to undo" } }
        $failures += & $step 'Undo journal emptied' { if (@(Get-TweakJournal).Count) { throw 'journal still has records' } }

        # Every setting must be back to its ORIGINAL value. When two tweaks touched
        # the same setting (e.g. High Performance then Ultimate Performance), only
        # the first change holds the original, so check that one.
        $bad = 0
        $seen = @{}
        foreach ($r in $journal) {
            foreach ($c in @($r.Changes | Where-Object { $_ })) {
                if ($seen.ContainsKey($c.Id)) { continue }
                $seen[$c.Id] = $true
                if (-not (Test-ChangeRestored $c)) {
                    $bad++
                    Write-TestResult $false "Not restored after undo [$($r.Title)]: $(Get-ChangeDescription $c)"
                }
            }
        }
        if ($bad -eq 0) { Write-TestResult $true "All $changeCount change(s) are back to their original values" }
        $failures += $bad

        # Startup manager round trip on a harmless test entry
        $failures += & $step 'Startup item turn off / on' {
            $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $approved = "$($Script:ApprovedHKCU)\Run"
            Write-RegData $run 'LerxnaSelfTest' "`"$env:windir\System32\notepad.exe`"" 'String'
            try {
                $item = @(Get-StartupItems | Where-Object { $_.Type -eq 'Run' -and $_.ValueName -eq 'LerxnaSelfTest' }) | Select-Object -First 1
                if (-not $item) { throw 'test entry not found by the scanner' }
                if (-not $item.Enabled) { throw 'test entry should start enabled' }
                if (-not (Disable-StartupItem $item)) { throw 'could not turn it off' }
                if (Get-ApprovedEnabled $approved 'LerxnaSelfTest') { throw 'still enabled after turning off' }
                if (-not (Enable-StartupItem $item)) { throw 'could not turn it back on' }
                if (-not (Get-ApprovedEnabled $approved 'LerxnaSelfTest')) { throw 'still disabled after turning on' }
            } finally {
                Remove-RegData $run 'LerxnaSelfTest'
                Remove-RegData $approved 'LerxnaSelfTest'
            }
        }

        if (Test-Path -LiteralPath "$($Script:JournalFile).before-selftest") {
            Move-Item -LiteralPath "$($Script:JournalFile).before-selftest" -Destination $Script:JournalFile -Force
        }
    }

    Write-Host ""
    if ($failures -eq 0) { Write-Host "SELF-TEST PASSED" -ForegroundColor Green; return 0 }
    Write-Host "SELF-TEST FAILED ($failures problem(s)) - log: $Script:LogFile" -ForegroundColor Red
    return 1
}

# ============================================================
# MAIN
# ============================================================
# Runs a section; if anything unexpected goes wrong it shows the error
# and goes back to the menu instead of closing the window.
function Invoke-Safely {
    param([scriptblock]$Block, [string]$Name)
    try { & $Block }
    catch {
        Write-Host ""
        Warn "$Name ran into a problem: $($_.Exception.Message)"
        Info "Nothing else was changed. Details are in the log: $Script:LogFile"
        Write-Log ("ERROR in {0}: {1} (line {2})" -f $Name, $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber)
    }
}

if ($SelfTest) {
    Write-Log "Lerxna Optimizer v$($Script:Version) self-test started"
    $code = @(Invoke-SelfTest)[-1]
    exit ([int]$code)
}

Show-Banner
Write-Log "Lerxna Optimizer v$($Script:Version) started$(if ($Script:Preview) { ' (preview mode)' })"
Invoke-Safely -Name 'PC scan' -Block {
    $Script:Sys = Get-SystemProfile
    Write-Host "  Scanning startup apps..." -ForegroundColor Gray
    $Script:LastScan = @(Get-StartupItems)
    Show-SystemReport
}
if (-not $Script:Sys) {
    Stop-WithMessage "Couldn't read basic information about this PC (Windows Management Instrumentation may be broken). Try restarting, then run Lerxna Optimizer again."
}

Write-Host ""
if ($Script:Preview) {
    Write-Host "  PREVIEW MODE: go through anything you like - nothing will be changed." -ForegroundColor Cyan
} else {
    Pink "  You'll be asked before every change. Press Y to apply, N to skip."
    Pink "  Not sure? Pick option 8 (Preview mode) to see exactly what would change first."
    if (Ask "Create a System Restore point before making changes?" 'REC' 'Lets you roll back everything if you don''t like a change.') {
        Invoke-Safely -Name 'Restore point' -Block { New-RestorePoint }
    }
}

$running = $true
while ($running) {
    Section "Main Menu"
    Write-Host "   [1] Full optimization  (tweaks -> startup scan -> junk cleanup)"
    Write-Host "   [2] System tweaks only"
    Write-Host "   [3] Startup & background apps scanner"
    Write-Host "   [4] Clean junk files / repair Windows"
    Write-Host "   [5] Undo / restore"
    Write-Host "   [6] Create a restore point"
    Write-Host "   [7] Show my PC scan again"
    if ($Script:Preview) { Write-Host "   [8] Preview mode: ON  (nothing is being changed - pick 8 to turn it off)" -ForegroundColor Cyan }
    else                 { Write-Host "   [8] Preview mode: OFF (turn on to see what would change without changing anything)" }
    Write-Host "   [0] Finish & exit"
    $choice = Read-Choice "Choose [0-8]:" @('0', '1', '2', '3', '4', '5', '6', '7', '8')

    switch ($choice) {
        '1' {
            Invoke-Safely -Name 'System tweaks'   -Block { Invoke-TweakWizard }
            Invoke-Safely -Name 'Startup scanner' -Block { Invoke-StartupScanner }
            Invoke-Safely -Name 'Junk cleanup'    -Block { Invoke-Cleanup }
            Invoke-Safely -Name 'Summary'         -Block { Complete-Run }
        }
        '2' { Invoke-Safely -Name 'System tweaks'   -Block { Invoke-TweakWizard } }
        '3' { Invoke-Safely -Name 'Startup scanner' -Block { Invoke-StartupScanner } }
        '4' { Invoke-Safely -Name 'Junk cleanup'    -Block { Invoke-Cleanup } }
        '5' { Invoke-Safely -Name 'Undo menu'       -Block { Invoke-UndoMenu } }
        '6' { Invoke-Safely -Name 'Restore point'   -Block { New-RestorePoint } }
        '7' {
            Invoke-Safely -Name 'PC scan' -Block {
                $Script:Sys = Get-SystemProfile
                $Script:LastScan = @(Get-StartupItems)
                Show-SystemReport
            }
        }
        '8' {
            if ($Script:Preview) { Save-PreviewReport }
            $Script:Preview = -not $Script:Preview
            if ($Script:Preview) { Done "Preview mode ON - everything will show what it WOULD change, and change nothing." }
            else { Done "Preview mode OFF - changes will be applied again (you'll still be asked first)." }
        }
        '0' { $running = $false }
    }
}

if (($Script:Applied.Count + $Script:StartupChanges) -ne $Script:SummaryShownAt) {
    Invoke-Safely -Name 'Summary' -Block { Complete-Run }
}

Write-Host ""
Pink  "  =================================================="
Pink  "   Lerxna Optimizer - Complete!"
Pink  "  =================================================="
Write-Host ""
# Keep the window open so the summary can be read (it would close instantly otherwise)
try { Read-Host "  Press Enter to close" | Out-Null } catch {}
