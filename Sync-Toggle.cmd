@echo off
setlocal
set "DIR=%~dp0"
set "SCRIPT=%DIR%sync.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%DIR%sync_auto.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%DIR%sync_corrige_v3.ps1"
if not exist "%SCRIPT%" exit /b 1

set "PIDFILE=%DIR%sync.pid"
if exist "%PIDFILE%" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=0;try{$p=[int](Get-Content -LiteralPath '%PIDFILE%' -ErrorAction Stop)}catch{};if($p -gt 0 -and (Get-Process -Id $p -ErrorAction SilentlyContinue)){exit 0}else{exit 1}"
  if not errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Stop
    exit /b 0
  )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
exit /b %errorlevel%
