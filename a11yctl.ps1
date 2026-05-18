[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$commandArgs = @($CommandArgs)
$homeDir = if (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
$runtimeRelativePath = 'backend-scripts/powershell/a11yctl.runtime.ps1'
$runtimeCandidates = @(
    (Join-Path $PSScriptRoot $runtimeRelativePath),
    (Join-Path $homeDir '.a11yctl/scripts/powershell/a11yctl.runtime.ps1')
)

$runtimeScript = $null
foreach ($candidate in $runtimeCandidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
        $runtimeScript = $candidate
        break
    }
}

if (-not $runtimeScript -and -not [string]::IsNullOrWhiteSpace($homeDir)) {
    $fallbackRuntime = Join-Path $homeDir '.a11yctl/scripts/powershell/a11yctl.runtime.ps1'
    $fallbackDir = Split-Path -Path $fallbackRuntime -Parent
    $runtimeUrl = "https://raw.githubusercontent.com/A11yDevs/a11yctl/main/$runtimeRelativePath"

    try {
        if (-not (Test-Path $fallbackDir)) {
            New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
        }

        Invoke-WebRequest -Uri $runtimeUrl -OutFile $fallbackRuntime -UseBasicParsing
        if (Test-Path $fallbackRuntime) {
            $runtimeScript = $fallbackRuntime
        }
    }
    catch {
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
