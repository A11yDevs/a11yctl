[CmdletBinding()]
param(
    [string]$RuntimePath
)

$ErrorActionPreference = 'Stop'

function Write-Info($Message)  { Write-Host "[fix-a11yctl] $Message" -ForegroundColor Cyan }
function Write-Warn($Message)  { Write-Host "[fix-a11yctl] $Message" -ForegroundColor Yellow }
function Write-Ok($Message)    { Write-Host "[fix-a11yctl] $Message" -ForegroundColor Green }
function Write-Bad($Message)   { Write-Host "[fix-a11yctl] $Message" -ForegroundColor Red }

function Find-A11yRuntimePath {
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $candidates += Join-Path $env:USERPROFILE '.a11yctl\scripts\powershell\a11yctl.runtime.ps1'
        $candidates += Join-Path $env:USERPROFILE '.a11yctl\backend-scripts\powershell\a11yctl.runtime.ps1'
    }

    $cmd = Get-Command a11yctl -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $root = Split-Path -Path $cmd.Source -Parent
        $candidates += Join-Path $root 'backend-scripts\powershell\a11yctl.runtime.ps1'
        $candidates += Join-Path $root 'scripts\powershell\a11yctl.runtime.ps1'
        $candidates += Join-Path $root 'a11yctl.runtime.ps1'
    }

    $cmd2 = Get-Command ea11ctl -ErrorAction SilentlyContinue
    if ($cmd2 -and $cmd2.Source) {
        $root = Split-Path -Path $cmd2.Source -Parent
        $candidates += Join-Path $root 'backend-scripts\powershell\a11yctl.runtime.ps1'
        $candidates += Join-Path $root 'scripts\powershell\a11yctl.runtime.ps1'
        $candidates += Join-Path $root 'a11yctl.runtime.ps1'
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $found = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.a11yctl') -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'a11yctl.runtime.ps1' } |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    return $null
}

function Get-TextEncodingUtf8Bom {
    return New-Object System.Text.UTF8Encoding($true)
}

function Add-A11yArgumentQuotingHelpers {
    param([string]$Content)

    if ($Content -match 'function ConvertTo-A11yctlNativeArgument') {
        return $Content
    }

    $helper = @'

function ConvertTo-A11yctlNativeArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    # Windows PowerShell costuma transformar ArgumentList em uma linha única.
    # Sem quoting manual, caminhos como "C:\Users\Nome - Nome Número" viram:
    # C:\Users\Nome | - | Nome | Número
    # e o QEMU acusa: "-: invalid option".
    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    # Regra compatível com CommandLineToArgvW:
    # - aspas internas precisam ser escapadas;
    # - barras invertidas antes de aspas precisam ser duplicadas;
    # - barras invertidas finais precisam ser duplicadas antes da aspa final.
    $escaped = $Argument -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function ConvertTo-A11yctlNativeArgumentList {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    return (($Arguments | ForEach-Object {
        ConvertTo-A11yctlNativeArgument -Argument ([string]$_)
    }) -join ' ')
}

function ConvertTo-A11yctlDebugCommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    return ((ConvertTo-A11yctlNativeArgument -Argument $Executable) + ' ' + (ConvertTo-A11yctlNativeArgumentList -Arguments $Arguments))
}
'@

    if ($Content -match 'function Invoke-QemuVMStart\s*\{') {
        return [regex]::Replace($Content, 'function Invoke-QemuVMStart\s*\{', ($helper + "`nfunction Invoke-QemuVMStart {"), 1)
    }

    return $helper + "`n" + $Content
}


function Add-A11yQemuStartupSafetyPatch {
    param([string]$Content, [System.Collections.Generic.List[string]]$Changes)

    $patched = $Content

    $helpers = @'

function Normalize-QemuDiskInterface {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'virtio' }
    switch ($Value.ToLowerInvariant()) {
        'virtio' { return 'virtio' }
        'ide'    { return 'ide' }
        'scsi'   { return 'scsi' }
        'sata'   { return 'sata' }
        'none'   { return 'none' }
        default  { return $null }
    }
}

function Normalize-QemuDiskCache {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'writeback' }
    switch ($Value.ToLowerInvariant()) {
        'writeback'    { return 'writeback' }
        'writethrough' { return 'writethrough' }
        'none'         { return 'none' }
        'unsafe'       { return 'unsafe' }
        'directsync'   { return 'directsync' }
        default        { return $null }
    }
}

function Normalize-QemuDiskDiscard {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'unmap' }
    switch ($Value.ToLowerInvariant()) {
        'unmap'  { return 'unmap' }
        'ignore' { return 'ignore' }
        'off'    { return 'ignore' }
        'none'   { return 'ignore' }
        default  { return $null }
    }
}

function Normalize-QemuVideoDevice {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'virtio-vga' }

    $norm = $Value.Trim()
    switch ($norm.ToLowerInvariant()) {
        'std'        { return 'std' }
        'vga'        { return 'VGA' }
        'none'       { return 'none' }
        'virtio-std' { return 'virtio-vga' }
        'virtio-vga' { return 'virtio-vga' }
        'qxl'        { return 'qxl-vga' }
        'qxl-vga'    { return 'qxl-vga' }
        'cirrus'     { return 'cirrus-vga' }
        'cirrus-vga' { return 'cirrus-vga' }
        default      { return $null }
    }
}

function Test-QemuWslStyleVirtfsPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ($Path -match '^(?i)(/[a-z]/|/mnt/[a-z]/|/Users/)')
}
'@

    if (($patched -notmatch 'function Normalize-QemuDiskInterface') -and ($patched -match 'function Get-QemuDesktopDisplayArgs\s*\{')) {
        $patched = [regex]::Replace($patched, 'function Get-QemuDesktopDisplayArgs\s*\{', ($helpers + "`nfunction Get-QemuDesktopDisplayArgs {"), 1)
        [void]$Changes.Add('Helpers de normalizacao QEMU adicionados: disk-if, cache, discard, video e paths virtfs.')
    }

    $videoPattern = "if \(-not \[string\]::IsNullOrWhiteSpace\(\$VideoDevice\)\) \{\s*\$args \+= @\('-device', \$VideoDevice\)\s*\}"
    if ([regex]::IsMatch($patched, $videoPattern)) {
        $videoReplacement = @'
$normalizedVideoDevice = Normalize-QemuVideoDevice -Value $VideoDevice
    if (-not [string]::IsNullOrWhiteSpace($normalizedVideoDevice) -and $normalizedVideoDevice -ne 'none') {
        if ($normalizedVideoDevice -eq 'std') {
            $args += @('-vga', 'std')
        }
        else {
            $args += @('-device', $normalizedVideoDevice)
        }
    }
'@
        $patched = [regex]::Replace($patched, $videoPattern, $videoReplacement, 1)
        [void]$Changes.Add('Video corrigido: std agora gera -vga std; valores invalidos nao sao repassados ao QEMU.')
    }

    $virtfsPattern = "function Test-QemuVirtfsSupport \{\s*param\(\[string\]\$QemuExecutable\)\s*try \{"
    if ([regex]::IsMatch($patched, $virtfsPattern)) {
        $virtfsReplacement = @'
function Test-QemuVirtfsSupport {
    param([string]$QemuExecutable)

    if (Test-IsWindowsHost) {
        return $false
    }

    try {
'@
        $patched = [regex]::Replace($patched, $virtfsPattern, $virtfsReplacement, 1)
        [void]$Changes.Add('Virtfs/9p desativado por padrao no Windows; o script passa a preferir SMB ou sem share.')
    }

    $sharePattern = "if \(Test-QemuVirtfsSupport -QemuExecutable \$qemuExecutable\) \{\s*\$hostHomeShareMode = '9p'\s*Write-[A-Za-z0-9]+Info \"Compartilhando host home via 9p: \$\(\$hostHomeShare\.HostPath\) -> \$\(\$hostHomeShare\.GuestMountPoint\)\"\s*\}\s*else \{\s*\$smbSupportInfo = Get-QemuUserNetSmbSupportInfo -QemuExecutable \$qemuExecutable\s*\}"
    if ([regex]::IsMatch($patched, $sharePattern)) {
        $shareReplacement = @'
if ((-not (Test-IsWindowsHost)) -and (Test-QemuVirtfsSupport -QemuExecutable $qemuExecutable) -and (-not (Test-QemuWslStyleVirtfsPath -Path $hostHomeShare.HostPath))) {
                $hostHomeShareMode = '9p'
                Write-EA11Info "Compartilhando host home via 9p: $($hostHomeShare.HostPath) -> $($hostHomeShare.GuestMountPoint)"
            }
            else {
                $smbSupportInfo = Get-QemuUserNetSmbSupportInfo -QemuExecutable $qemuExecutable
            }
'@
        $patched = [regex]::Replace($patched, $sharePattern, $shareReplacement, 1)
        [void]$Changes.Add('Selecao de compartilhamento corrigida: Windows nao tenta 9p; usa SMB quando possivel.')
    }

    $oldFallback = "if \(\(-not \$alive\) -and \(Test-IsWindowsHost\) -and \(\$accelMode -eq 'auto'\)\) \{"
    if ([regex]::IsMatch($patched, $oldFallback)) {
        $patched = [regex]::Replace($patched, $oldFallback, "if ((-not `$alive) -and (Test-IsWindowsHost) -and (`$accelMode -in @('auto','whpx'))) {", 1)
        [void]$Changes.Add('Fallback WHPX -> TCG ativado tambem quando accel=whpx, nao apenas auto.')
    }

    $assignPattern = "\$diskInterface = \[string\]\$runtimeCfg\['QEMU_DISK_IF'\]\s*\$diskCache = \[string\]\$runtimeCfg\['QEMU_DISK_CACHE'\]\s*\$diskDiscard = \[string\]\$runtimeCfg\['QEMU_DISK_DISCARD'\]\s*\$videoDevice = \[string\]\$runtimeCfg\['QEMU_VIDEO_DEVICE'\]"
    if ([regex]::IsMatch($patched, $assignPattern)) {
        $assignReplacement = @'
$diskInterface = Normalize-QemuDiskInterface -Value ([string]$runtimeCfg['QEMU_DISK_IF'])
    if ($null -eq $diskInterface) { Write-EA11Warn "Interface de disco invalida '$($runtimeCfg['QEMU_DISK_IF'])'. Usando 'virtio'."; $diskInterface = 'virtio' }

    $diskCache = Normalize-QemuDiskCache -Value ([string]$runtimeCfg['QEMU_DISK_CACHE'])
    if ($null -eq $diskCache) { Write-EA11Warn "Cache de disco invalido '$($runtimeCfg['QEMU_DISK_CACHE'])'. Usando 'writeback'."; $diskCache = 'writeback' }

    $diskDiscard = Normalize-QemuDiskDiscard -Value ([string]$runtimeCfg['QEMU_DISK_DISCARD'])
    if ($null -eq $diskDiscard) { Write-EA11Warn "Descarte/TRIM invalido '$($runtimeCfg['QEMU_DISK_DISCARD'])'. Usando 'unmap'."; $diskDiscard = 'unmap' }

    $videoDevice = Normalize-QemuVideoDevice -Value ([string]$runtimeCfg['QEMU_VIDEO_DEVICE'])
    if ($null -eq $videoDevice) { Write-EA11Warn "Video invalido '$($runtimeCfg['QEMU_VIDEO_DEVICE'])'. Usando 'virtio-vga'."; $videoDevice = 'virtio-vga' }
'@
        $patched = [regex]::Replace($patched, $assignPattern, $assignReplacement, 1)
        [void]$Changes.Add('Valores antigos invalidos no config agora sao normalizados no start.')
    }

    if ($patched -notmatch 'PATCH_A11YCTL_QEMU_STARTUP_SAFETY_APPLIED') {
        $patched = "# PATCH_A11YCTL_QEMU_STARTUP_SAFETY_APPLIED`r`n" + $patched
        [void]$Changes.Add('Marcador de patch de startup QEMU adicionado.')
    }

    return $patched
}

function Patch-A11yRuntimeContent {
    param([string]$Content)

    $patched = $Content
    $changes = New-Object System.Collections.Generic.List[string]

    # Linux guest mount point seguro: não usa o nome cru do Windows em /home/...
    $oldGuest = 'GuestMountPoint = "/home/$hostUser"'
    $newGuest = 'GuestMountPoint = "/home/$safeUser"'
    if ($patched.Contains($oldGuest)) {
        $patched = $patched.Replace($oldGuest, $newGuest)
        [void]$changes.Add('GuestMountPoint agora usa $safeUser em vez de $hostUser.')
    }

    # Insere helper de quoting.
    $before = $patched
    $patched = Add-A11yArgumentQuotingHelpers -Content $patched
    if ($patched -ne $before) {
        [void]$changes.Add('Helpers de quoting adicionados para argumentos nativos do Windows.')
    }

    # Corrige hashtables Start-Process: ArgumentList = $qemuArgs
    $patternHashtable = 'ArgumentList\s*=\s*\$qemuArgs'
    $replacementHashtable = 'ArgumentList = (ConvertTo-A11yctlNativeArgumentList -Arguments $qemuArgs)'
    $count1 = ([regex]::Matches($patched, $patternHashtable)).Count
    if ($count1 -gt 0) {
        $patched = [regex]::Replace($patched, $patternHashtable, $replacementHashtable)
        [void]$changes.Add("ArgumentList em hashtable corrigido ($count1 ocorrência(s)).")
    }

    # Corrige retries: $startParams.ArgumentList = $qemuArgs
    $patternRetry = '\$startParams\.ArgumentList\s*=\s*\$qemuArgs'
    $replacementRetry = '$startParams.ArgumentList = ConvertTo-A11yctlNativeArgumentList -Arguments $qemuArgs'
    $count2 = ([regex]::Matches($patched, $patternRetry)).Count
    if ($count2 -gt 0) {
        $patched = [regex]::Replace($patched, $patternRetry, $replacementRetry)
        [void]$changes.Add("ArgumentList em retries corrigido ($count2 ocorrência(s)).")
    }

    # Corrige last-qemu-cmd.txt para mostrar comando copiável com aspas corretas.
    $patternDebug = 'Set-Content\s+-Path\s+\$debugCmdFile\s+-Value\s+\("\$qemuExecutable "\s*\+\s*\(\$qemuArgs\s+-join\s+'' ''\)\)'
    $replacementDebug = 'Set-Content -Path $debugCmdFile -Value (ConvertTo-A11yctlDebugCommandLine -Executable $qemuExecutable -Arguments $qemuArgs)'
    $count3 = ([regex]::Matches($patched, $patternDebug)).Count
    if ($count3 -gt 0) {
        $patched = [regex]::Replace($patched, $patternDebug, $replacementDebug)
        [void]$changes.Add('last-qemu-cmd.txt agora salva o comando com aspas corretas.')
    }

    $patched = Add-A11yQemuStartupSafetyPatch -Content $patched -Changes $changes

    if ($patched -notmatch 'PATCH_A11YCTL_QEMU_PATHS_APPLIED') {
        $patched = "# PATCH_A11YCTL_QEMU_PATHS_APPLIED`r`n" + $patched
        [void]$changes.Add('Marcador de patch adicionado.')
    }

    return @{
        Content = $patched
        Changes = $changes.ToArray()
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($RuntimePath)) {
        $RuntimePath = Find-A11yRuntimePath
    }

    if ([string]::IsNullOrWhiteSpace($RuntimePath) -or -not (Test-Path -LiteralPath $RuntimePath)) {
        throw "Não foi possivel encontrar o a11yctl.runtime.ps1. Passe o caminho manualmente: .\fix-a11yctl-qemu-paths.ps1 -RuntimePath 'C:\caminho\a11yctl.runtime.ps1'"
    }

    Write-Info "Runtime encontrado: $RuntimePath"

    $original = [System.IO.File]::ReadAllText($RuntimePath, [System.Text.Encoding]::UTF8)
    $result = Patch-A11yRuntimeContent -Content $original
    $patched = [string]$result.Content
    $changes = @($result.Changes)

    if ($patched -eq $original) {
        Write-Warn 'Nenhuma alteração aplicada. O arquivo pode já estar corrigido ou mudou de estrutura.'
        exit 0
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$RuntimePath.bak-$timestamp"
    Copy-Item -LiteralPath $RuntimePath -Destination $backupPath -Force
    Write-Info "Backup criado: $backupPath"

    [System.IO.File]::WriteAllText($RuntimePath, $patched, (Get-TextEncodingUtf8Bom))

    Write-Ok 'Patch aplicado com sucesso.'
    foreach ($change in $changes) {
        Write-Host "  - $change"
    }

    Write-Host ''
    Write-Info 'Agora rode:'
    Write-Host '  a11yctl debug on'
    Write-Host '  a11yctl vm start'
    Write-Host ''
    Write-Info 'Se precisar desfazer:'
    Write-Host "  Copy-Item '$backupPath' '$RuntimePath' -Force"
}
catch {
    Write-Bad $_.Exception.Message
    exit 1
}
