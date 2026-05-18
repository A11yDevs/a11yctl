$env:NO_COLOR = '1'

Set-StrictMode -Version Latest

function global:Get-TestScriptPath {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $testsDir = $PSScriptRoot
    $repoDir = (Resolve-Path (Join-Path $testsDir '..' '..')).Path
    $path = Join-Path $repoDir $FileName

    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) {
        throw "Arquivo de teste nao encontrado: $path"
    }

    return $path
}

function global:Invoke-ScriptWithHome {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$HomePath
    )

    $pwsh = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pwsh
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    foreach ($arg in $allArgs) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $psi.Environment['HOME'] = $HomePath
    $psi.Environment['USERPROFILE'] = $HomePath

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    return [PSCustomObject]@{
        ExitCode = $proc.ExitCode
        Output = ($stdout + [Environment]::NewLine + $stderr)
    }
}

Describe 'a11yctl PowerShell minimum tests' {
    It 'comandos legados removidos retornam erro claro' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('migrate-state', '--quiet') -HomePath $testHome
        $result.ExitCode | Should -Not -Be 0 -Because 'migrate-state foi removido'
        $result.Output | Should -Match 'Comando desconhecido'

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('migrate', '--quiet') -HomePath $testHome
        $result.ExitCode | Should -Not -Be 0 -Because 'migrate foi removido'
        $result.Output | Should -Match 'Comando desconhecido'

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('uninstall') -HomePath $testHome
        $result.ExitCode | Should -Not -Be 0 -Because 'uninstall foi removido'
        $result.Output | Should -Match 'Comando desconhecido'

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('update') -HomePath $testHome
        $result.ExitCode | Should -Not -Be 0 -Because 'alias update foi removido'
        $result.Output | Should -Match 'Comando desconhecido'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'ea11ctl.ps1 avisa depreciacao e delega para a11yctl' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'ea11ctl.ps1') -Arguments @('version') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'ea11ctl.*obsoleto'
        $result.Output | Should -Match 'a11yctl v'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }



    It 'comando invalido retorna erro e mensagem clara' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('comando-inexistente') -HomePath $testHome

        $result.ExitCode | Should -Not -Be 0 -Because "Comando invalido deve falhar"
        $result.Output | Should -Match 'Comando desconhecido'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'argumento em branco e ignorado antes do comando valido' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('   ', 'version') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'a11yctl v'
        $result.Output | Should -Not -Match 'Comando desconhecido:'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'version retorna a versao da CLI' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('version') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'a11yctl v'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm version retorna metadados da VM (nao versao da CLI)' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'version') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'backend=qemu'
        $result.Output | Should -Match 'local_tag='
        $result.Output | Should -Not -Match '^a11yctl v'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm check-update retorna status de atualizacao da VM' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'check-update') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'backend=qemu'
        $result.Output | Should -Match 'local_tag='
        $result.Output | Should -Match 'latest_tag='
        $result.Output | Should -Match 'update_status='
        $result.Output | Should -Not -Match '^a11yctl v'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm list sem VMs registradas retorna sucesso e mensagem informativa' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'list') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'Nenhuma VM QEMU registrada'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm install com disco existente nao tenta download e retorna sucesso' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        $stateDir = Join-Path $testHome '.a11yctl'
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        Set-Content -Path (Join-Path $stateDir 'debian-a11ydevs.qcow2') -Value 'existing-disk' -NoNewline

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'install') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'Imagem QCOW2 ja existe'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm list com estado registrado exibe VM como stopped' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        $qemuStateDir = Join-Path $testHome '.a11yctl/qemu'
        New-Item -ItemType Directory -Path $qemuStateDir -Force | Out-Null

        $statePath = Join-Path $qemuStateDir 'demo.json'
        '{"name":"demo","sshPort":2222,"pid":0}' | Set-Content -Path $statePath -NoNewline

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'list') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'demo \(qemu\) - stopped - ssh:2222'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm status sem VM registrada nao falha e informa ausencia de estado' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'status', '-n', 'demo') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match "VM QEMU 'demo' nao registrada"

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm status com estado registrado exibe detalhes da VM' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        $qemuStateDir = Join-Path $testHome '.a11yctl/qemu'
        New-Item -ItemType Directory -Path $qemuStateDir -Force | Out-Null

        $statePath = Join-Path $qemuStateDir 'demo.json'
        '{"name":"demo","sshPort":2222,"pid":0,"systemDisk":"/tmp/system.qcow2","userDataDisk":"/tmp/data.qcow2"}' | Set-Content -Path $statePath -NoNewline

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'status', '-n', 'demo') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match 'VM: demo'
        $result.Output | Should -Match 'State: stopped'
        $result.Output | Should -Match 'SSH: localhost:2222'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm config path retorna caminho do arquivo de configuracao' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'path') -HomePath $testHome

        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match '\.a11yctl.*/qemu/config\.env|\.a11yctl\\qemu\\config\.env'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm config set seguido de get --raw persiste valor' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $setResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'set', 'memory', '2048') -HomePath $testHome
        $setResult.ExitCode | Should -Be 0 -Because "Saida do script: $($setResult.Output)"
        $setResult.Output | Should -Match 'Configuração atualizada|Configuracao atualizada'

        $getResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'get', 'memory', '--raw') -HomePath $testHome
        $getResult.ExitCode | Should -Be 0 -Because "Saida do script: $($getResult.Output)"
        $getResult.Output | Should -Match 'QEMU_MEMORY_MB=2048'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm config get com chave invalida falha' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'get', 'inexistente') -HomePath $testHome

        $result.ExitCode | Should -Not -Be 0 -Because 'chave invalida em vm config get deve falhar'
        $result.Output | Should -Match 'configuração desconhecida|configuracao desconhecida'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm config reset restaura memory para valor padrao' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $setResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'set', 'memory', '2048') -HomePath $testHome
        $setResult.ExitCode | Should -Be 0 -Because "Saida do script: $($setResult.Output)"

        $resetResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'reset') -HomePath $testHome
        $resetResult.ExitCode | Should -Be 0 -Because "Saida do script: $($resetResult.Output)"
        $resetResult.Output | Should -Match 'Configuracao resetada para defaults'

        $getResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'config', 'get', 'memory', '--raw') -HomePath $testHome
        $getResult.ExitCode | Should -Be 0 -Because "Saida do script: $($getResult.Output)"
        $getResult.Output | Should -Match 'QEMU_MEMORY_MB=4096'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'vm logs exibe logs de todas as VMs e por nome' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        $logDir = Join-Path $testHome '.a11yctl/logs'
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null

        Set-Content -Path (Join-Path $logDir 'vm1.qemu.log') -Value 'log-vm1' -NoNewline
        Set-Content -Path (Join-Path $logDir 'vm2.qemu.log') -Value 'log-vm2' -NoNewline

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'logs') -HomePath $testHome
        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match '==> Log: '
        $result.Output | Should -Match 'log-vm1'
        $result.Output | Should -Match 'log-vm2'

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'logs', '-n', 'vm1') -HomePath $testHome
        $result.ExitCode | Should -Be 0 -Because "Saida do script: $($result.Output)"
        $result.Output | Should -Match '==> Log da VM'
        $result.Output | Should -Match 'log-vm1'

        $result = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('vm', 'logs', '-n', 'inexistente') -HomePath $testHome
        $result.ExitCode | Should -Not -Be 0 -Because 'log inexistente deve falhar'
        $result.Output | Should -Match 'Nenhum log encontrado'

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'debug on, status e off funcionam com flag persistente' {
        $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("a11yctl-ps-test-" + [Guid]::NewGuid().ToString('N'))
        $testHome = Join-Path $tmpRoot 'home'
        New-Item -ItemType Directory -Path $testHome -Force | Out-Null

        $onResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('debug', 'on') -HomePath $testHome
        $onResult.ExitCode | Should -Be 0 -Because "Saida do script: $($onResult.Output)"
        $onResult.Output | Should -Match 'DEBUG ativado'
        Test-Path (Join-Path $testHome '.a11yctl/qemu/debug.enabled') | Should -BeTrue

        $statusResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('debug', 'status') -HomePath $testHome
        $statusResult.ExitCode | Should -Be 0 -Because "Saida do script: $($statusResult.Output)"
        $statusResult.Output | Should -Match 'DEBUG está ativado'

        $offResult = Invoke-ScriptWithHome -ScriptPath (Get-TestScriptPath -FileName 'a11yctl.ps1') -Arguments @('debug', 'off') -HomePath $testHome
        $offResult.ExitCode | Should -Be 0 -Because "Saida do script: $($offResult.Output)"
        $offResult.Output | Should -Match 'DEBUG desativado'
        Test-Path (Join-Path $testHome '.a11yctl/qemu/debug.enabled') | Should -BeFalse

        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
