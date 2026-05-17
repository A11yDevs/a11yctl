Set-StrictMode -Version Latest

$testsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = (Resolve-Path (Join-Path $testsDir '..' '..')).Path
$a11yctlScript = Join-Path $repoDir 'a11yctl.ps1'
$legacyWrapperScript = Join-Path $repoDir 'ea11ctl.ps1'

function Invoke-ScriptWithHome {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$HomePath
    )

    $oldHome = $env:HOME
    $oldUserProfile = $env:USERPROFILE

    try {
        $env:HOME = $HomePath
        $env:USERPROFILE = $HomePath

        $pwsh = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
        $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
        $output = & $pwsh @allArgs 2>&1

        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output | Out-String)
        }
    }
    finally {
        $env:HOME = $oldHome
        $env:USERPROFILE = $oldUserProfile
    }
}

Describe 'a11yctl PowerShell minimum tests' {
    It 'migrate-state copia legado sem sobrescrever e preserva origem' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $home = Join-Path $tmpRoot 'home'
        $legacy = Join-Path $home '.emacs-a11y-vm'
        $target = Join-Path $home '.a11yctl'

        New-Item -ItemType Directory -Path (Join-Path $legacy 'qemu') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $target 'qemu') -Force | Out-Null

        Set-Content -Path (Join-Path $legacy 'debian-a11ydevs.qcow2') -Value 'legacy-disk' -NoNewline
        Set-Content -Path (Join-Path $target 'debian-a11ydevs.qcow2') -Value 'current-disk' -NoNewline
        Set-Content -Path (Join-Path $legacy 'qemu/debian-a11y.json') -Value '{"name":"debian-a11y"}' -NoNewline

        $result = Invoke-ScriptWithHome -ScriptPath $a11yctlScript -Arguments @('migrate-state', '--quiet') -HomePath $home

        $result.ExitCode | Should -Be 0
        (Get-Content -Path (Join-Path $target 'debian-a11ydevs.qcow2') -Raw) | Should -Be 'current-disk'
        Test-Path (Join-Path $target 'debian-a11ydevs.migrated.qcow2') | Should -BeTrue
        (Get-Content -Path (Join-Path $target 'debian-a11ydevs.migrated.qcow2') -Raw) | Should -Be 'legacy-disk'
        Test-Path (Join-Path $legacy 'debian-a11ydevs.qcow2') | Should -BeTrue

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'ea11ctl.ps1 avisa depreciacao e delega para a11yctl' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $home = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $home -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath $legacyWrapperScript -Arguments @('version') -HomePath $home

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'ea11ctl.*obsoleto'
        $result.Output | Should -Match 'a11yctl v'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'migrate-state sem legado nao falha' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $home = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $home -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath $a11yctlScript -Arguments @('migrate-state', '--quiet') -HomePath $home

        $result.ExitCode | Should -Be 0

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
