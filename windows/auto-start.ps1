$ErrorActionPreference = "Stop"

$Folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script = Join-Path $Folder "sync.ps1"
if (-not (Test-Path -LiteralPath $Script)) {
    $Script = Join-Path $Folder "sync_auto.ps1"
}

if (-not (Test-Path -LiteralPath $Script)) {
    Write-Host "Impossible de trouver sync.ps1 ou sync_auto.ps1 dans ce dossier." -ForegroundColor Red
    exit 1
}

$RunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-Item -Path $RunPath -Force | Out-Null
$Command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Script + '" -Background'
Set-ItemProperty -Path $RunPath -Name "SyncMirror" -Value $Command -Type String

Write-Host "Démarrage automatique activé pour votre session Windows." -ForegroundColor Green
Write-Host "Aucun droit administrateur n'est nécessaire."
Pause
