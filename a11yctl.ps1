$ErrorActionPreference = 'Stop'
$runtimeScript = Join-Path $PSScriptRoot 'backend-scripts/powershell/a11yctl.runtime.ps1'

if (-not (Test-Path $runtimeScript)) {
    Write-Host '[a11yctl] Runtime do PowerShell nao encontrado. Reinstale a CLI.' -ForegroundColor Red
    exit 1
}

. $runtimeScript
$commandArgs = @()
$scriptLeaf = Split-Path -Leaf $PSCommandPath
$rawCommandLineArgs = [System.Environment]::GetCommandLineArgs()

for ($i = 0; $i -lt $rawCommandLineArgs.Length; $i++) {
    if ((Split-Path -Leaf $rawCommandLineArgs[$i]) -ieq $scriptLeaf) {
        if (($i + 1) -lt $rawCommandLineArgs.Length) {
            $commandArgs = @($rawCommandLineArgs[($i + 1)..($rawCommandLineArgs.Length - 1)])
        }
        break
    }
}

if (($commandArgs.Count -eq 0) -and $MyInvocation.UnboundArguments) {
    $commandArgs = @($MyInvocation.UnboundArguments)
}

Invoke-A11CtlRuntime -Args $commandArgs
