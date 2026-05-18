[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$targetScript = Join-Path $PSScriptRoot 'a11yctl.ps1'
if (-not (Test-Path $targetScript)) {
    Write-Host '[ea11ctl] Nao foi possivel localizar a11yctl.ps1.' -ForegroundColor Red
    exit 1
}

Write-Host '[ea11ctl] Aviso: ea11ctl esta obsoleto e sera removido em versao futura. Use a11yctl.' -ForegroundColor Yellow
& $targetScript @Args
if ($LASTEXITCODE -is [int]) {
    exit $LASTEXITCODE
}

if ($?) {
    exit 0
}

exit 1