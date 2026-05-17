$ErrorActionPreference = 'Stop'
$commandArgs = @($args)
$runtimeScript = Join-Path $PSScriptRoot 'backend-scripts/powershell/a11yctl.runtime.ps1'

if (-not (Test-Path $runtimeScript)) {
    Write-Host '[a11yctl] Runtime do PowerShell nao encontrado. Reinstale a CLI.' -ForegroundColor Red
    exit 1
}

. $runtimeScript
Invoke-A11CtlRuntime -CommandArgs $commandArgs
