# a11yctl-reinstall.ps1
# Script de reinstalação rápida do a11yctl (PowerShell)
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$installer = Join-Path $scriptDir 'install.ps1'

if (Test-Path $installer) {
    Write-Host '[a11yctl-reinstall] Executando install.ps1...'
    & $installer
} else {
    Write-Host '[a11yctl-reinstall] install.ps1 não encontrado no diretório do a11yctl.' -ForegroundColor Red
    exit 1
}
