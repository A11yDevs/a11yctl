# a11yctl-uninstall.ps1
# Script de desinstalação do a11yctl (PowerShell)
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$binNames = @('a11yctl', 'ea11ctl', 'a11yctl-reinstall', 'a11yctl-uninstall')
$binDirs = @("$env:USERPROFILE/.a11yctl/bin", "$env:USERPROFILE/.local/bin", "$env:USERPROFILE/bin")

foreach ($bin in $binNames) {
    foreach ($dir in $binDirs) {
        $binPath = Join-Path $dir $bin
        if (Test-Path $binPath) {
            Write-Host "Removendo $binPath"
            Remove-Item $binPath -Force -ErrorAction SilentlyContinue
        }
    }
    foreach ($ext in @('', '.cmd', '.ps1')) {
        $localPath = Join-Path $scriptDir ($bin + $ext)
        if (Test-Path $localPath) {
            Write-Host "Removendo $localPath"
            Remove-Item $localPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$runtimePath = Join-Path $scriptDir 'backend-scripts/powershell/a11yctl.runtime.ps1'
if (Test-Path $runtimePath) {
    Write-Host "Removendo $runtimePath"
    Remove-Item $runtimePath -Force -ErrorAction SilentlyContinue
}

$runtimeDir = Join-Path $scriptDir 'backend-scripts/powershell'
if (Test-Path $runtimeDir) {
    Remove-Item $runtimeDir -Force -ErrorAction SilentlyContinue
}

$backendDir = Join-Path $scriptDir 'backend-scripts'
if (Test-Path $backendDir) {
    Remove-Item $backendDir -Force -ErrorAction SilentlyContinue
}

# Opcional: remover scripts de backend e estado
$resp = Read-Host 'Deseja remover também o diretório de estado (~/.a11yctl)? [s/N]'
if ($resp -match '^[sSyY]$') {
    $stateDir = Join-Path $env:USERPROFILE '.a11yctl'
    Remove-Item $stateDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Diretório ~/.a11yctl removido."
} else {
    Write-Host "Diretório ~/.a11yctl preservado."
}
