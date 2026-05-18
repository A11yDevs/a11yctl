# a11yctl-reinstall.ps1
# Script de reinstalação rápida do a11yctl (PowerShell)
param()

$INSTALL_OWNER  = 'A11yDevs'
$INSTALL_REPO   = 'a11yctl'
$INSTALL_BRANCH = 'main'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$installer = Join-Path $scriptDir 'install.ps1'

if (-not (Test-Path $installer)) {
    $cacheBust   = [int64]([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds
    $installerUrl = "https://raw.githubusercontent.com/$INSTALL_OWNER/$INSTALL_REPO/$INSTALL_BRANCH/install.ps1?cb=$cacheBust"
    Write-Host "[a11yctl-reinstall] Baixando install.ps1 de $installerUrl ..." -ForegroundColor Cyan
    try {
        $installer = Join-Path ([System.IO.Path]::GetTempPath()) "a11yctl-install-$cacheBust.ps1"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installer -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "[a11yctl-reinstall] Falha ao baixar install.ps1: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host '[a11yctl-reinstall] Executando install.ps1...'
& $installer
