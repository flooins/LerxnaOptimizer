# ============================================================
#            Lerxna Optimizer - Windows Setup Script
#                    Run as Administrator
# ============================================================

# Check for admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Please run this script as Administrator!" -ForegroundColor Red
    Exit
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Pink  { param($msg) Write-Host $msg -ForegroundColor Magenta }
function Done  { param($msg) Write-Host "   [OK] $msg" -ForegroundColor Green }
function Skip  { param($msg) Write-Host "   [--] Skipped: $msg" -ForegroundColor DarkGray }

function Ask {
    param($question)
    Write-Host ""
    Write-Host "  >> $question " -ForegroundColor Magenta -NoNewline
    Write-Host "[Y/N]: " -ForegroundColor White -NoNewline
    $response = Read-Host
    return ($response -match "^[Yy]$")
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host ""
Pink  "  =================================================="
Pink  "   _                             "
Pink  "  | |    ___ _ __ _  ___ __   __ _ "
Pink  "  | |   / _ \ '__| |/ / '_ \ / _' |"
Pink  "  | |__|  __/ |  |   <| | | | (_| |"
Pink  "  |_____\___|_|  |_|\_\_| |_|\__,_|"
Pink  ""
Pink  "        O p t i m i z e r  v1.0"
Pink  "  =================================================="
Write-Host ""
Pink  "  You will be asked about each section."
Pink  "  Press Y to apply, N to skip."
Pink  "  =================================================="
Write-Host ""
Start-Sleep -Seconds 1

# ============================================================
# 1. VISUAL EFFECTS
# ============================================================
if (Ask "Optimize Visual Effects? (disables animations, keeps thumbnails/fonts)") {
    Pink "`n  Applying Visual Effects settings..."

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    If (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "VisualFXSetting" -Type DWord -Value 3
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Type DWord -Value 0
    reg add "HKCU\Control Panel\Desktop" /v "DragFullWindows" /t REG_SZ /d "1" /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f | Out-Null

    Done "Visual Effects configured."
} else { Skip "Visual Effects" }

# ============================================================
# 2. DARK MODE
# ============================================================
if (Ask "Enable Dark Mode?") {
    Pink "`n  Enabling Dark Mode..."

    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "ColorPrevalence" /t REG_DWORD /d 0 /f | Out-Null

    Done "Dark Mode enabled."
} else { Skip "Dark Mode" }

# ============================================================
# 3. FILE EXPLORER
# ============================================================
if (Ask "Configure File Explorer? (show file extensions, hidden files, open to This PC)") {
    Pink "`n  Configuring File Explorer..."

    $explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $explorerPath -Name "HideFileExt" -Type DWord -Value 0
    Set-ItemProperty -Path $explorerPath -Name "Hidden" -Type DWord -Value 1
    Set-ItemProperty -Path $explorerPath -Name "LaunchTo" -Type DWord -Value 1

    Done "File Explorer configured."
} else { Skip "File Explorer" }

# ============================================================
# 4. TASKBAR
# ============================================================
if (Ask "Configure Taskbar? (align left, search icon only, remove widgets/chat buttons)") {
    Pink "`n  Configuring Taskbar..."

    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAl" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 1 /f | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarMn" /t REG_DWORD /d 0 /f | Out-Null

    Done "Taskbar configured."
} else { Skip "Taskbar" }

# ============================================================
# 5. POWER PLAN
# ============================================================
if (Ask "Set Power Plan to High Performance? (disables sleep/hibernation)") {
    Pink "`n  Setting Power Plan..."

    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    If ($LASTEXITCODE -ne 0) {
        powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    }
    powercfg /change standby-timeout-ac 0 | Out-Null
    powercfg /change hibernate-timeout-ac 0 | Out-Null
    powercfg /h off | Out-Null

    Done "Power Plan set to High Performance."
} else { Skip "Power Plan" }

# ============================================================
# 6. ONEDRIVE
# ============================================================
if (Ask "Disable and remove OneDrive?") {
    Pink "`n  Disabling OneDrive..."

    taskkill /f /im "OneDrive.exe" 2>$null | Out-Null
    $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    If (!(Test-Path $onedrive)) { $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
    If (Test-Path $onedrive) { Start-Process $onedrive "/uninstall" -NoNewWindow -Wait }
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSync" /t REG_DWORD /d 1 /f | Out-Null
    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null | Out-Null

    Done "OneDrive disabled."
} else { Skip "OneDrive" }

# ============================================================
# 7. CORTANA
# ============================================================
if (Ask "Disable Cortana and Bing search in taskbar?") {
    Pink "`n  Disabling Cortana..."

    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "CortanaConsent" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "DisableWebSearch" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "ConnectedSearchUseWeb" /t REG_DWORD /d 0 /f | Out-Null

    Done "Cortana disabled."
} else { Skip "Cortana" }

# ============================================================
# 8. TELEMETRY & PRIVACY
# ============================================================
if (Ask "Disable Windows Telemetry and Data Collection?") {
    Pink "`n  Disabling Telemetry..."

    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "DoNotShowFeedbackNotifications" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableCdp" /t REG_DWORD /d 0 /f | Out-Null
    Disable-ScheduledTask -TaskName "SustainabilityTelemetry" -TaskPath "\Microsoft\Windows\Sustainability\" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft Compatibility Appraiser Exp" -TaskPath "\Microsoft\Windows\Application Experience\" -ErrorAction SilentlyContinue | Out-Null

    Done "Telemetry & Privacy configured."
} else { Skip "Telemetry & Privacy" }

# ============================================================
# 9. WINDOWS AI / RECALL
# ============================================================
if (Ask "Disable Windows AI, Recall and Copilot features?") {
    Pink "`n  Disabling Windows AI features..."

    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "AllowRecallEnablement" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null

    Done "Windows AI / Recall / Copilot disabled."
} else { Skip "Windows AI / Recall" }

# ============================================================
# 10. BLOAT SERVICES
# ============================================================
if (Ask "Disable bloat services? (AMD/Intel/Adobe telemetry, Edge updater, Xbox auto-start)") {
    Pink "`n  Disabling Bloat Services..."

    sc.exe config "GamingServices" start= demand 2>$null | Out-Null
    Set-Service -Name "GameInputSvc" -StartupType Manual -ErrorAction SilentlyContinue
    Get-ScheduledTask | Where-Object {$_.TaskName -like "*Xbox*"} | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "MicrosoftEdgeUpdateTaskMachineCore" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "MicrosoftEdgeUpdateTaskMachineUA" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Adobe Acrobat Update Task" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Launch Adobe CCXProcess" -ErrorAction SilentlyContinue | Out-Null
    sc.exe stop "AdobeARMservice" 2>$null | Out-Null
    sc.exe delete "AdobeARMservice" 2>$null | Out-Null
    Stop-Service -Name "AUEPLauncher" -Force -ErrorAction SilentlyContinue
    sc.exe delete "AUEPLauncher" 2>$null | Out-Null
    Disable-ScheduledTask -TaskName "AMDInstallUEP" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "StartAUEP" -ErrorAction SilentlyContinue | Out-Null

    Done "Bloat services disabled."
} else { Skip "Bloat Services" }

# ============================================================
# 11. BLOAT APPS
# ============================================================
if (Ask "Remove built-in bloat apps? (Bing apps, Maps, Skype, Teams, Clipchamp, etc.)") {
    Pink "`n  Removing Bloat Apps..."

    $bloatApps = @(
        "Microsoft.3DBuilder"
        "Microsoft.BingWeather"
        "Microsoft.BingNews"
        "Microsoft.BingFinance"
        "Microsoft.BingSports"
        "Microsoft.BingTravel"
        "Microsoft.BingFoodAndDrink"
        "Microsoft.BingHealthAndFitness"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Maps"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MicrosoftStickyNotes"
        "Microsoft.MixedReality.Portal"
        "Microsoft.Office.OneNote"
        "Microsoft.OneConnect"
        "Microsoft.People"
        "Microsoft.Print3D"
        "Microsoft.SkypeApp"
        "Microsoft.Todos"
        "Microsoft.WindowsAlarms"
        "Microsoft.WindowsCamera"
        "Microsoft.windowscommunicationsapps"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.YourPhone"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "Microsoft.Advertising.Xaml"
        "Microsoft.MSPaint"
        "Microsoft.Whiteboard"
        "MicrosoftTeams"
        "Cortana"
        "Microsoft.549981C3F5F10"
        "Microsoft.PowerAutomateDesktop"
        "Microsoft.Clipchamp"
        "Microsoft.MicrosoftJournal"
        "Microsoft.OutlookForWindows"
        "Microsoft.Windows.DevHome"
    )

    foreach ($app in $bloatApps) {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }

    Done "Bloat apps removed."
} else { Skip "Bloat Apps" }

# ============================================================
# 12. STARTUP CLEANUP
# ============================================================
if (Ask "Clean up startup items? (AMD noise suppression, Adobe sync, OneDrive, touch keyboard)") {
    Pink "`n  Cleaning Startup Items..."

    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AMDNoiseSuppression" /f 2>$null | Out-Null
    reg delete "HKU\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AMDNoiseSuppression" /f 2>$null | Out-Null
    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "Adobe Acrobat Synchronizer" /f 2>$null | Out-Null
    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AdobeCollabSync" /f 2>$null | Out-Null
    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\TextInputHost.exe" /v "Debugger" /t REG_SZ /d "invalid" /f | Out-Null

    Done "Startup items cleaned."
} else { Skip "Startup Cleanup" }

# ============================================================
# 13. ADS & SUGGESTIONS
# ============================================================
if (Ask "Disable Windows ads, tips, suggestions and lock screen promotions?") {
    Pink "`n  Disabling Ads & Suggestions..."

    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v "ScoobeSystemSettingEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v "EnableFeeds" /t REG_DWORD /d 0 /f | Out-Null

    Done "Ads & Suggestions disabled."
} else { Skip "Ads & Suggestions" }

# ============================================================
# 14. FASTER SHUTDOWN & BSOD TWEAKS
# ============================================================
if (Ask "Apply system tweaks? (faster shutdown, don't auto-restart on BSOD)") {
    Pink "`n  Applying System Tweaks..."

    reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "WaitToKillServiceTimeout" /t REG_SZ /d "2000" /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "AutoReboot" /t REG_DWORD /d 0 /f | Out-Null

    Done "System tweaks applied."
} else { Skip "System Tweaks" }

# ============================================================
# 15. POWERSHELL & CMD AS ADMIN
# ============================================================
if (Ask "Set PowerShell, CMD and Windows Terminal to always run as Administrator?") {
    Pink "`n  Configuring Admin mode for terminals..."

    $powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $cmdExe        = "$env:SystemRoot\System32\cmd.exe"
    $wtExe         = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"

    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$powershellExe" /t REG_SZ /d "RUNASADMIN" /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$powershellExe" /t REG_SZ /d "RUNASADMIN" /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$cmdExe" /t REG_SZ /d "RUNASADMIN" /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$cmdExe" /t REG_SZ /d "RUNASADMIN" /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$wtExe" /t REG_SZ /d "RUNASADMIN" /f | Out-Null

    Done "PowerShell, CMD & Windows Terminal set to always run as Admin."
} else { Skip "PowerShell/CMD Admin Mode" }

# ============================================================
# 16. LOCATION SERVICES
# ============================================================
if (Ask "Disable all Location Services?") {
    Pink "`n  Disabling Location Services..."

    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v "DisableLocation" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v "DisableLocationScripting" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v "DisableWindowsLocationProvider" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v "DisableSensors" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v "Value" /t REG_SZ /d "Deny" /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v "SensorPermissionState" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /t REG_SZ /d "Deny" /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /t REG_SZ /d "Deny" /f | Out-Null
    Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskName "WindowsActionDialog" -TaskPath "\Microsoft\Windows\Location\" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Notifications" -TaskPath "\Microsoft\Windows\Location\" -ErrorAction SilentlyContinue | Out-Null

    Done "All Location Services disabled."
} else { Skip "Location Services" }

# ============================================================
# RESTART EXPLORER
# ============================================================
Write-Host ""
Pink "  Restarting Explorer to apply visual changes..."
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process "explorer.exe"

# ============================================================
# DONE
# ============================================================
Write-Host ""
Pink  "  =================================================="
Pink  "   Lerxna Optimizer - Complete!"
Pink  "  =================================================="
Write-Host ""
Pink  "  Restart your PC now for all changes to take effect."
Pink  "  =================================================="
Write-Host ""
