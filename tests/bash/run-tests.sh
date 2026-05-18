run_vm_logs_test() {
    local tmp sandbox home logdir output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"
    logdir="$home/.a11yctl/logs"

    mkdir -p "$sandbox/backend-scripts" "$home" "$logdir"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    # Cria logs de duas VMs
    echo 'log-vm1' > "$logdir/vm1.qemu.log"
    echo 'log-vm2' > "$logdir/vm2.qemu.log"

    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm logs 2>&1)"
    assert_contains "$output" '==> Log: ' "vm logs lista logs existentes"
    assert_contains "$output" 'log-vm1' "vm logs exibe conteudo do log da vm1"
    assert_contains "$output" 'log-vm2' "vm logs exibe conteudo do log da vm2"

    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm logs -n vm1 2>&1)"
    assert_contains "$output" '==> Log da VM' "vm logs -n mostra header correto"
    assert_contains "$output" 'log-vm1' "vm logs -n mostra conteudo correto"
    assert_not_equals "$output" "" "vm logs -n nao retorna vazio"

    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm logs -n inexistente 2>&1 || true)"
    assert_contains "$output" 'Nenhum log encontrado' "vm logs -n inexistente informa ausencia"

    rm -rf "$tmp"
}
#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_equals() {
    local left="$1"
    local right="$2"
    local label="$3"

    if [[ "$left" == "$right" ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_file_exists() {
    local path="$1"
    local label="$2"

    if [[ -f "$path" ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_not_equals() {
    local left="$1"
    local right="$2"
    local label="$3"

    if [[ "$left" != "$right" ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

run_removed_legacy_commands_test() {
    local tmp home output status
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" migrate-state --quiet 2>&1)"
    status=$?
    set -e
    assert_not_equals "$status" "0" "migrate-state removido retorna falha"
    assert_contains "$output" "Comando desconhecido" "migrate-state removido informa comando desconhecido"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" migrate --quiet 2>&1)"
    status=$?
    set -e
    assert_not_equals "$status" "0" "migrate removido retorna falha"
    assert_contains "$output" "Comando desconhecido" "migrate removido informa comando desconhecido"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" uninstall 2>&1)"
    status=$?
    set -e
    assert_not_equals "$status" "0" "uninstall removido retorna falha"
    assert_contains "$output" "Comando desconhecido" "uninstall removido informa comando desconhecido"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" update 2>&1)"
    status=$?
    set -e
    assert_not_equals "$status" "0" "alias update removido retorna falha"
    assert_contains "$output" "Comando desconhecido" "alias update removido informa comando desconhecido"

    rm -rf "$tmp"
}

run_wrapper_test() {
    local tmp home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/ea11ctl" version 2>&1 || true)"

    assert_contains "$output" "Aviso: ea11ctl esta obsoleto" "wrapper ea11ctl exibe aviso de depreciacao"
    assert_contains "$output" "a11yctl v" "wrapper ea11ctl delega para a11yctl"

    rm -rf "$tmp"
}



run_unknown_command_test() {
    local tmp home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" comando-inexistente 2>&1)"
    local status=$?
    set -e

    assert_not_equals "$status" "0" "comando invalido retorna falha"
    assert_contains "$output" "Comando desconhecido" "comando invalido informa erro"

    rm -rf "$tmp"
}

run_wrapper_invalid_command_test() {
    local tmp home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/ea11ctl" comando-inexistente 2>&1)"
    local status=$?
    set -e

    assert_not_equals "$status" "0" "wrapper legado propaga erro de comando invalido"
    assert_contains "$output" "Aviso: ea11ctl esta obsoleto" "wrapper legado mantem aviso em erro"

    rm -rf "$tmp"
}

run_self_update_force_mock_test() {
    local tmp sandbox home mockbin output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"
    mockbin="$tmp/mockbin"

    mkdir -p "$sandbox/backend-scripts" "$home" "$mockbin"

    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    cp "$REPO_DIR/ea11ctl" "$sandbox/ea11ctl"
    cp "$REPO_DIR/a11yctl.ps1" "$sandbox/a11yctl.ps1"
    cp "$REPO_DIR/a11yctl.cmd" "$sandbox/a11yctl.cmd"
    cp "$REPO_DIR/ea11ctl.ps1" "$sandbox/ea11ctl.ps1"
    cp "$REPO_DIR/ea11ctl.cmd" "$sandbox/ea11ctl.cmd"
    cp "$REPO_DIR/install.sh" "$sandbox/install.sh"
    cp "$REPO_DIR/install.ps1" "$sandbox/install.ps1"
    cp "$REPO_DIR/VERSION" "$sandbox/VERSION"
    cp "$REPO_DIR/backend-scripts/common.sh" "$sandbox/backend-scripts/common.sh"
    cp "$REPO_DIR/backend-scripts/qemu.sh" "$sandbox/backend-scripts/qemu.sh"
    cp "$REPO_DIR/backend-scripts/host.sh" "$sandbox/backend-scripts/host.sh"

    chmod +x "$sandbox/a11yctl" "$sandbox/ea11ctl"

    cat > "$mockbin/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
url=""

while (($#)); do
    case "$1" in
        -o)
            out="$2"
            shift 2
            ;;
        --max-time|-H)
            shift 2
            ;;
        -s|-S|-L|-f|-fsSL|-sSL)
            shift
            ;;
        *)
            if [[ "$1" == http* ]]; then
                url="$1"
            fi
            shift
            ;;
    esac
done

[[ -n "$url" ]] || exit 1

if [[ "$url" == *"/commits/"* ]]; then
    printf '{"sha":"mocksha123"}'
    exit 0
fi

path="${url#*raw.githubusercontent.com/}"
path="${path#*/}"
path="${path#*/}"
path="${path#*/}"
path="${path%%\?*}"

case "$path" in
    VERSION)
        content='9.9.9'
        ;;
    a11yctl)
        content='#!/usr/bin/env bash
echo "mock a11yctl"'
        ;;
    ea11ctl)
        content='#!/usr/bin/env bash
echo "mock ea11ctl"'
        ;;
    backend-scripts/common.sh)
        content='#!/usr/bin/env bash
echo "mock common"'
        ;;
    backend-scripts/qemu.sh)
        content='#!/usr/bin/env bash
echo "mock qemu"'
        ;;
    backend-scripts/host.sh)
        content='#!/usr/bin/env bash
echo "mock host"'
        ;;
    *)
        content="# mock $path"
        ;;
esac

if [[ -n "$out" ]]; then
    mkdir -p "$(dirname "$out")"
    printf '%s\n' "$content" > "$out"
else
    printf '%s\n' "$content"
fi
EOF

    chmod +x "$mockbin/curl"

    output="$(PATH="$mockbin:$PATH" HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" self-update --force 2>&1)"
    assert_equals "$?" "0" "self-update --force com curl mock retorna sucesso"
    assert_contains "$output" "a11yctl atualizado para v9.9.9" "self-update reporta versao mockada"
    assert_equals "$(cat "$sandbox/VERSION")" "9.9.9" "self-update atualiza arquivo VERSION no sandbox"
    assert_contains "$(cat "$sandbox/backend-scripts/qemu.sh")" "mock qemu" "self-update atualiza backend script via mock"

    rm -rf "$tmp"
}

run_self_update_no_force_up_to_date_test() {
    local tmp sandbox home mockbin output before_version after_version
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"
    mockbin="$tmp/mockbin"

    mkdir -p "$sandbox/backend-scripts" "$home" "$mockbin"

    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    cp "$REPO_DIR/VERSION" "$sandbox/VERSION"
    cp "$REPO_DIR/backend-scripts/common.sh" "$sandbox/backend-scripts/common.sh"
    cp "$REPO_DIR/backend-scripts/qemu.sh" "$sandbox/backend-scripts/qemu.sh"
    cp "$REPO_DIR/backend-scripts/host.sh" "$sandbox/backend-scripts/host.sh"
    chmod +x "$sandbox/a11yctl"

    before_version="$(tr -d '[:space:]' < "$sandbox/VERSION")"

    cat > "$mockbin/curl" << EOF
#!/usr/bin/env bash
set -euo pipefail

for arg in "\$@"; do
    if [[ "\$arg" == http* ]] && [[ "\$arg" == *"/releases/latest"* ]]; then
        printf '{"tag_name":"v%s"}\n' "$before_version"
        exit 0
    fi
    if [[ "\$arg" == http* ]] && [[ "\$arg" == *"/VERSION"* ]]; then
        printf '%s\n' "$before_version"
        exit 0
    fi
done

exit 1
EOF
    chmod +x "$mockbin/curl"

    output="$(PATH="$mockbin:$PATH" HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" self-update 2>&1)"
    assert_equals "$?" "0" "self-update sem force retorna sucesso quando ja atualizado"
    assert_contains "$output" "atualizado" "self-update sem force informa que ja esta atualizado"

    after_version="$(tr -d '[:space:]' < "$sandbox/VERSION")"
    assert_equals "$after_version" "$before_version" "self-update sem force nao altera VERSION quando ja atualizado"

    rm -rf "$tmp"
}

run_self_update_no_force_remote_newer_test() {
    local tmp sandbox home mockbin output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"
    mockbin="$tmp/mockbin"

    mkdir -p "$sandbox/backend-scripts" "$home" "$mockbin"

    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    cp "$REPO_DIR/ea11ctl" "$sandbox/ea11ctl"
    cp "$REPO_DIR/a11yctl.ps1" "$sandbox/a11yctl.ps1"
    cp "$REPO_DIR/a11yctl.cmd" "$sandbox/a11yctl.cmd"
    cp "$REPO_DIR/ea11ctl.ps1" "$sandbox/ea11ctl.ps1"
    cp "$REPO_DIR/ea11ctl.cmd" "$sandbox/ea11ctl.cmd"
    cp "$REPO_DIR/install.sh" "$sandbox/install.sh"
    cp "$REPO_DIR/install.ps1" "$sandbox/install.ps1"
    cp "$REPO_DIR/VERSION" "$sandbox/VERSION"
    cp "$REPO_DIR/backend-scripts/common.sh" "$sandbox/backend-scripts/common.sh"
    cp "$REPO_DIR/backend-scripts/qemu.sh" "$sandbox/backend-scripts/qemu.sh"
    cp "$REPO_DIR/backend-scripts/host.sh" "$sandbox/backend-scripts/host.sh"
    chmod +x "$sandbox/a11yctl" "$sandbox/ea11ctl"

    cat > "$mockbin/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
url=""

while (($#)); do
    case "$1" in
        -o)
            out="$2"
            shift 2
            ;;
        --max-time|-H)
            shift 2
            ;;
        -s|-S|-L|-f|-fsSL|-sSL)
            shift
            ;;
        *)
            if [[ "$1" == http* ]]; then
                url="$1"
            fi
            shift
            ;;
    esac
done

[[ -n "$url" ]] || exit 1

if [[ "$url" == *"/commits/"* ]]; then
    printf '{"sha":"mocksha456"}'
    exit 0
fi

path="${url#*raw.githubusercontent.com/}"
path="${path#*/}"
path="${path#*/}"
path="${path#*/}"
path="${path%%\?*}"

case "$path" in
    VERSION)
        content='8.8.8'
        ;;
    a11yctl)
        content='#!/usr/bin/env bash
echo "mock a11yctl newer"'
        ;;
    ea11ctl)
        content='#!/usr/bin/env bash
echo "mock ea11ctl newer"'
        ;;
    backend-scripts/common.sh)
        content='#!/usr/bin/env bash
echo "mock common newer"'
        ;;
    backend-scripts/qemu.sh)
        content='#!/usr/bin/env bash
echo "mock qemu newer"'
        ;;
    backend-scripts/host.sh)
        content='#!/usr/bin/env bash
echo "mock host newer"'
        ;;
    *)
        content="# mock newer $path"
        ;;
esac

if [[ -n "$out" ]]; then
    mkdir -p "$(dirname "$out")"
    printf '%s\n' "$content" > "$out"
else
    printf '%s\n' "$content"
fi
EOF
    chmod +x "$mockbin/curl"

    output="$(PATH="$mockbin:$PATH" HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" self-update 2>&1)"
    assert_equals "$?" "0" "self-update sem force atualiza quando remoto e mais novo"
    assert_contains "$output" "Atualizando a11yctl de v" "self-update sem force anuncia atualizacao"
    assert_equals "$(tr -d '[:space:]' < "$sandbox/VERSION")" "8.8.8" "self-update sem force atualiza para versao remota"
    assert_contains "$(cat "$sandbox/backend-scripts/qemu.sh")" "mock qemu newer" "self-update sem force atualiza backend script"

    rm -rf "$tmp"
}

run_vm_list_dispatch_test() {
    local tmp sandbox home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" > "${HOME}/vm-dispatch.log"
exit 0
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm list 2>&1)"
    assert_equals "$?" "0" "vm list retorna sucesso"
    assert_equals "$(cat "$home/vm-dispatch.log")" "list" "vm list despacha para backend com comando list"
    assert_equals "$output" "" "vm list sem erro nao imprime diagnostico extra"

    rm -rf "$tmp"
}

run_vm_install_dispatch_args_test() {
    local tmp sandbox home
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" > "${HOME}/vm-install-dispatch.log"
exit 0
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm install --tag v1.2.3 --force-download >/dev/null 2>&1
    assert_equals "$?" "0" "vm install retorna sucesso"
    assert_equals "$(cat "$home/vm-install-dispatch.log")" "install --tag v1.2.3 --force-download" "vm install preserva argumentos para backend"

    rm -rf "$tmp"
}

run_vm_backend_error_propagation_test() {
    local tmp sandbox home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "backend-fail" >&2
exit 42
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm list 2>&1)"
    local status=$?
    set -e

    assert_equals "$status" "42" "erro do backend em vm list e propagado"
    assert_contains "$output" "backend-fail" "erro do backend e exibido ao usuario"

    rm -rf "$tmp"
}

run_vm_list_reject_backend_option_test() {
    local tmp home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" vm list --backend qemu 2>&1)"
    local status=$?
    set -e

    assert_not_equals "$status" "0" "vm list com --backend falha"
    assert_contains "$output" "opcao de backend foi removida" "vm list com --backend informa erro correto"

    rm -rf "$tmp"
}

run_vm_status_dispatch_test() {
    local tmp sandbox home
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" > "${HOME}/vm-status-dispatch.log"
exit 0
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm status -n demo >/dev/null 2>&1
    assert_equals "$?" "0" "vm status retorna sucesso"
    assert_equals "$(cat "$home/vm-status-dispatch.log")" "status -n demo" "vm status despacha argumentos corretamente"

    rm -rf "$tmp"
}

run_vm_config_show_dispatch_test() {
    local tmp sandbox home
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" > "${HOME}/vm-config-show.log"
exit 0
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm config >/dev/null 2>&1
    assert_equals "$?" "0" "vm config (show default) retorna sucesso"
    assert_equals "$(cat "$home/vm-config-show.log")" "config show" "vm config sem acao despacha show"

    rm -rf "$tmp"
}

run_vm_config_get_set_reset_dispatch_test() {
    local tmp sandbox home
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${HOME}/vm-config-actions.log"
exit 0
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm config get memory --raw >/dev/null 2>&1
    assert_equals "$?" "0" "vm config get retorna sucesso"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm config set memory 4096 >/dev/null 2>&1
    assert_equals "$?" "0" "vm config set retorna sucesso"

    HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm config reset >/dev/null 2>&1
    assert_equals "$?" "0" "vm config reset retorna sucesso"

    local actions
    actions="$(cat "$home/vm-config-actions.log")"
    assert_contains "$actions" "config get memory --raw" "vm config get despacha argumentos"
    assert_contains "$actions" "config set memory 4096" "vm config set despacha argumentos"
    assert_contains "$actions" "config reset" "vm config reset despacha argumentos"

    rm -rf "$tmp"
}

run_vm_config_backend_error_test() {
    local tmp sandbox home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    sandbox="$tmp/sandbox"
    home="$tmp/home"

    mkdir -p "$sandbox/backend-scripts" "$home"
    cp "$REPO_DIR/a11yctl" "$sandbox/a11yctl"
    chmod +x "$sandbox/a11yctl"

    cat > "$sandbox/backend-scripts/common.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/host.sh" << 'EOF'
#!/usr/bin/env bash
EOF
    cat > "$sandbox/backend-scripts/qemu.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "config-fail" >&2
exit 33
EOF
    chmod +x "$sandbox/backend-scripts/qemu.sh" "$sandbox/backend-scripts/host.sh"

    set +e
    output="$(HOME="$home" USERPROFILE="$home" bash "$sandbox/a11yctl" vm config get memory 2>&1)"
    local status=$?
    set -e

    assert_equals "$status" "33" "vm config propaga codigo de erro do backend"
    assert_contains "$output" "config-fail" "vm config exibe mensagem de erro do backend"

    rm -rf "$tmp"
}

run_debug_command_persistence_test() {
    local tmp home output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" debug on 2>&1)"
    assert_equals "$?" "0" "debug on retorna sucesso"
    assert_contains "$output" "DEBUG ativado" "debug on informa ativacao"
    assert_file_exists "$home/.a11yctl/qemu/debug.enabled" "debug on cria flag persistente"

    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" debug status 2>&1)"
    assert_equals "$?" "0" "debug status retorna sucesso"
    assert_contains "$output" "DEBUG está ativado" "debug status detecta modo ativo"

    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" debug off 2>&1)"
    assert_equals "$?" "0" "debug off retorna sucesso"
    assert_contains "$output" "DEBUG desativado" "debug off informa desativacao"
    if [[ -f "$home/.a11yctl/qemu/debug.enabled" ]]; then
        fail "debug off remove flag persistente"
    else
        pass "debug off remove flag persistente"
    fi

    rm -rf "$tmp"
}

run_removed_legacy_commands_test
run_wrapper_test
run_unknown_command_test
run_wrapper_invalid_command_test
run_self_update_force_mock_test
run_self_update_no_force_up_to_date_test
run_self_update_no_force_remote_newer_test
run_vm_list_dispatch_test
run_vm_install_dispatch_args_test
run_vm_backend_error_propagation_test
run_vm_list_reject_backend_option_test
run_vm_status_dispatch_test
run_vm_config_show_dispatch_test
run_vm_config_get_set_reset_dispatch_test
run_vm_config_backend_error_test
run_debug_command_persistence_test
run_vm_logs_test

printf '\nResumo: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

exit 0
