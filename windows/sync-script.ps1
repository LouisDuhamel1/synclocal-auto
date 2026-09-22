# ============================================================
# SYNCHRONISATION MIROIR
# Premier lancement : choix Source / Destination
# Lancements suivants : fonctionnement silencieux
# Contrôle SHA256 périodique
#
# Utilisation :
#   sync_corrige.ps1          -> lance la synchronisation
#   sync_corrige.ps1 -Reconfigure -> change Source / Destination
#   sync_corrige.ps1 -Stop    -> arrête une instance en cours
# ============================================================

param(
    [switch]$Reconfigure,
    [switch]$Stop,
    [switch]$Background
)

$ConfigFile = Join-Path $PSScriptRoot "sync-config.json"
$PidFile    = Join-Path $PSScriptRoot "sync.pid"

# Vérification SHA256 complète toutes les 30 minutes
$IntervalleControle = 0

# Démarrage automatique à l'ouverture de session Windows.
# Utilise HKCU : aucun droit administrateur n'est nécessaire.
$StartupName = "SyncMirror"
$StartupCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Background'

function Activer-DemarrageAutomatique {
    try {
        $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        New-Item -Path $runPath -Force | Out-Null
        Set-ItemProperty -Path $runPath -Name $StartupName -Value $StartupCommand -Type String
    } catch {}
}


# ============================================================
# OUTILS
# ============================================================

function Choisir-Dossier {
    param([string]$Titre)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Fenêtre propriétaire invisible et toujours au premier plan.
    # Cela évite que la boîte de sélection soit cachée derrière PowerShell.
    $owner = New-Object System.Windows.Forms.Form
    $owner.Text = "Synchronisation"
    $owner.StartPosition = "CenterScreen"
    $owner.Size = New-Object System.Drawing.Size(1,1)
    $owner.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $owner.ShowInTaskbar = $false
    $owner.TopMost = $true
    $owner.Opacity = 0

    $owner.Show()
    $owner.Activate()

    try {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $Titre
        $dialog.ShowNewFolderButton = $true
        $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer

        $result = $dialog.ShowDialog($owner)

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }

        return $null
    }
    finally {
        $owner.Close()
        $owner.Dispose()
    }
}

function Charger-Configuration {
    if (-not (Test-Path -LiteralPath $ConfigFile)) {
        return $null
    }

    try {
        $cfg = Get-Content -LiteralPath $ConfigFile -Raw -ErrorAction Stop |
               ConvertFrom-Json -ErrorAction Stop

        if ($cfg.Source -and $cfg.Destination) {
            return $cfg
        }
    }
    catch {
        return $null
    }

    return $null
}

function Creer-Configuration {
    Clear-Host

    Write-Host ""
    Write-Host "============================================"
    Write-Host "     PREMIERE CONFIGURATION"
    Write-Host "============================================"
    Write-Host ""

    Write-Host "Choisis le dossier SOURCE." -ForegroundColor Cyan
    Write-Host "C'est le dossier contenant les fichiers originaux."
    Write-Host ""

    $source = Choisir-Dossier "CHOISIS LE DOSSIER SOURCE"

    if (-not $source) {
        Write-Host "Aucun dossier source sélectionné." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Source : $source" -ForegroundColor Green
    Write-Host ""

    Write-Host "Choisis maintenant le dossier DESTINATION." -ForegroundColor Cyan
    Write-Host "Ce dossier deviendra le miroir de la source."
    Write-Host ""

    $destination = Choisir-Dossier "CHOISIS LE DOSSIER DESTINATION"

    if (-not $destination) {
        Write-Host "Aucun dossier destination sélectionné." -ForegroundColor Red
        exit 1
    }

    $sourceFull = [System.IO.Path]::GetFullPath($source).TrimEnd('\')
    $destFull   = [System.IO.Path]::GetFullPath($destination).TrimEnd('\')

    if ($sourceFull -eq $destFull) {
        Write-Host ""
        Write-Host "ERREUR : Source et destination identiques." -ForegroundColor Red
        exit 1
    }

    # La destination ne doit pas être à l'intérieur de la source.
    if ($destFull.StartsWith($sourceFull + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host ""
        Write-Host "ERREUR : La destination est à l'intérieur de la source." -ForegroundColor Red
        Write-Host "Choisis deux emplacements séparés." -ForegroundColor Red
        exit 1
    }

    $cfg = [PSCustomObject]@{
        Source      = $source
        Destination = $destination
    }

    $cfg | ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8

    Write-Host ""
    Write-Host "Configuration enregistrée." -ForegroundColor Green
    Write-Host "Source      : $source"
    Write-Host "Destination : $destination"
    Write-Host ""

    return $cfg
}


# ============================================================
# ARRET
# ============================================================

if ($Stop) {
    if (Test-Path -LiteralPath $PidFile) {
        try {
            $storedPid = [int](Get-Content -LiteralPath $PidFile -ErrorAction Stop)
            $process = Get-Process -Id $storedPid -ErrorAction SilentlyContinue

            if ($process) {
                Stop-Process -Id $storedPid -Force
                Write-Host "Synchronisation arrêtée."
            }
            else {
                Write-Host "Aucune synchronisation active."
            }
        }
        catch {
            Write-Host "Impossible d'arrêter la synchronisation."
        }

        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Aucune synchronisation active."
    }

    exit
}


# ============================================================
# CONFIGURATION
# ============================================================

$configuration = Charger-Configuration

if ($Reconfigure) {
    $configuration = Creer-Configuration
}
elseif (-not $configuration) {
    $configuration = Creer-Configuration
}

$Source      = [string]$configuration.Source
$Destination = [string]$configuration.Destination

Activer-DemarrageAutomatique


# ============================================================
# LANCEMENT EN ARRIERE-PLAN
# ============================================================

if (-not $Background) {

    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        "`"$PSCommandPath`""
        "-Background"
    )

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $argList `
        -WindowStyle Hidden

    exit
}


# ============================================================
# EVITER PLUSIEURS INSTANCES
# ============================================================

if (Test-Path -LiteralPath $PidFile) {
    try {
        $oldPid = [int](Get-Content -LiteralPath $PidFile -ErrorAction Stop)
        $oldProcess = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

        if ($oldProcess -and $oldPid -ne $PID) {
            exit
        }
    }
    catch {
        # Le fichier PID est invalide : on le remplace.
    }
}

$PID | Set-Content -LiteralPath $PidFile -Encoding ASCII


# ============================================================
# NETTOYAGE A LA FERMETURE
# ============================================================

Register-EngineEvent PowerShell.Exiting -Action {
    if (Test-Path -LiteralPath $PidFile) {
        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    }
} | Out-Null


# ============================================================
# SYNCHRONISATION MIROIR
# ============================================================

$script:SynchronisationEnCours = $false

function Synchroniser {

    if ($script:SynchronisationEnCours) {
        return
    }

    $script:SynchronisationEnCours = $true

    try {
        if (-not (Test-Path -LiteralPath $Source)) {
            return
        }

        if (-not (Test-Path -LiteralPath $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }

        robocopy `
            $Source `
            $Destination `
            /MIR `
            /COPY:DAT `
            /DCOPY:DAT `
            /FFT `
            /XJ `
            /R:2 `
            /W:2 `
            /NP `
            /NDL `
            /NFL `
            | Out-Null
    }
    finally {
        $script:SynchronisationEnCours = $false
    }
}


# ============================================================
# VERIFICATION SHA256
# ============================================================

function Verifier {

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        return
    }

    $fichiersSource = Get-ChildItem `
        -LiteralPath $Source `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue

    $fichiersDestination = Get-ChildItem `
        -LiteralPath $Destination `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue

    $mapSource = @{}
    $mapDestination = @{}

    foreach ($fichier in $fichiersSource) {
        $relatif = $fichier.FullName.Substring($Source.Length).TrimStart('\')
        $mapSource[$relatif] = $fichier
    }

    foreach ($fichier in $fichiersDestination) {
        $relatif = $fichier.FullName.Substring($Destination.Length).TrimStart('\')
        $mapDestination[$relatif] = $fichier
    }

    foreach ($chemin in $mapSource.Keys) {

        if (-not $mapDestination.ContainsKey($chemin)) {
            Synchroniser
            return
        }

        $src = $mapSource[$chemin]
        $dst = $mapDestination[$chemin]

        if ($src.Length -ne $dst.Length) {
            Synchroniser
            return
        }

        $hashSrc = (Get-FileHash -LiteralPath $src.FullName -Algorithm SHA256).Hash
        $hashDst = (Get-FileHash -LiteralPath $dst.FullName -Algorithm SHA256).Hash

        if ($hashSrc -ne $hashDst) {
            Synchroniser
            return
        }
    }

    foreach ($chemin in $mapDestination.Keys) {

        if (-not $mapSource.ContainsKey($chemin)) {
            Synchroniser
            return
        }
    }
}


# ============================================================
# PREMIERE SYNCHRONISATION
# ============================================================

Synchroniser


# ============================================================
# SURVEILLANCE CONTINUE
# ============================================================

$Watcher = New-Object System.IO.FileSystemWatcher

$Watcher.Path = $Source
$Watcher.IncludeSubdirectories = $true

$Watcher.NotifyFilter =
    [System.IO.NotifyFilters]::FileName -bor
    [System.IO.NotifyFilters]::DirectoryName -bor
    [System.IO.NotifyFilters]::LastWrite -bor
    [System.IO.NotifyFilters]::Size

$Watcher.EnableRaisingEvents = $true


Register-ObjectEvent -InputObject $Watcher -EventName Created -Action {
    Start-Sleep -Milliseconds 1000
    Synchroniser
} | Out-Null

Register-ObjectEvent -InputObject $Watcher -EventName Changed -Action {
    Start-Sleep -Milliseconds 1000
    Synchroniser
} | Out-Null

Register-ObjectEvent -InputObject $Watcher -EventName Deleted -Action {
    Start-Sleep -Milliseconds 1000
    Synchroniser
} | Out-Null

Register-ObjectEvent -InputObject $Watcher -EventName Renamed -Action {
    Start-Sleep -Milliseconds 1000
    Synchroniser
} | Out-Null


# ============================================================
# CONTROLE PERIODIQUE
# ============================================================

$DernierControle = Get-Date

while ($true) {

    Start-Sleep -Seconds 5

    $MinutesEcoulees = ((Get-Date) - $DernierControle).TotalMinutes

    if ($MinutesEcoulees -ge $IntervalleControle) {

        Synchroniser
        Verifier

        $DernierControle = Get-Date
    }
}
