[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$commandArgs = @($CommandArgs)
$homeDir = if (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
$runtimeCandidates = @(
    (Join-Path $PSScriptRoot 'backend-scripts/powershell/a11yctl.runtime.ps1'),
    (Join-Path $homeDir '.a11yctl/scripts/powershell/a11yctl.runtime.ps1')
)

$runtimeScript = $null
foreach ($candidate in $runtimeCandidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
        $runtimeScript = $candidate
        break
    }
}

if (-not $runtimeScript) {
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
