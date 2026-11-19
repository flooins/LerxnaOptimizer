@echo off
title Lerxna Optimizer (preview)
rem ============================================================
rem  Double-click this file to see what Lerxna Optimizer WOULD change.
rem  Preview mode: nothing on your PC is changed.
rem  Keep it in the same folder as LerxnaOptimizer.ps1.
rem  It starts 64-bit Windows PowerShell with script blocking
rem  bypassed for this run only; the script then asks for
rem  Administrator rights by itself.
rem ============================================================

if not exist "%~dp0LerxnaOptimizer.ps1" goto missing

set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" set "PSEXE=powershell.exe"

"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0LerxnaOptimizer.ps1" -Preview
if errorlevel 1 pause
exit /b

:missing
echo.
echo   LerxnaOptimizer.ps1 was not found next to this file.
echo   Put Preview-LerxnaOptimizer.bat and LerxnaOptimizer.ps1 in the same folder.
echo   (If you downloaded a .zip, extract it first - don't run it from inside the zip.)
echo.
pause
exit /b 1
