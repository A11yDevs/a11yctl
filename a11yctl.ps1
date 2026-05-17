[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$commandArgs = @($CommandArgs)
$runtimeScript = Join-Path $PSScriptRoot 'backend-scripts/powershell/a11yctl.runtime.ps1'

if (-not (Test-Path $runtimeScript)) {
    Write-Host '[a11yctl] Runtime do PowerShell nao encontrado. Reinstale a CLI.' -ForegroundColor Red
    exit 1
}

. $runtimeScript
Invoke-A11CtlRuntime -CommandArgs $commandArgs

if ($null -ne $script:A11YCTL_EXIT_CODE) {
    exit ([int]$script:A11YCTL_EXIT_CODE)
}

if (-not $?) {
    exit 1
}

exit 0
