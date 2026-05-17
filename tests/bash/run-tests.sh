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

run_migrate_conflict_test() {
    local tmp home legacy target output
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    legacy="$home/.emacs-a11y-vm"
    target="$home/.a11yctl"

    mkdir -p "$legacy/qemu" "$target/qemu"
    printf 'legacy-disk\n' > "$legacy/debian-a11ydevs.qcow2"
    printf 'current-disk\n' > "$target/debian-a11ydevs.qcow2"
    printf '{"name":"debian-a11y"}\n' > "$legacy/qemu/debian-a11y.json"

    output="$(HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" migrate-state --quiet 2>&1)"
    assert_equals "$?" "0" "migrate-state retorna sucesso"

    local current_content migrated_content
    current_content="$(cat "$target/debian-a11ydevs.qcow2")"
    migrated_content="$(cat "$target/debian-a11ydevs.migrated.qcow2")"

    assert_equals "$current_content" "current-disk" "arquivo existente nao e sobrescrito"
    assert_equals "$migrated_content" "legacy-disk" "arquivo legado em conflito recebe sufixo .migrated"
    assert_file_exists "$target/qemu/debian-a11y.json" "estado qemu legado e copiado"
    assert_file_exists "$legacy/debian-a11ydevs.qcow2" "diretorio legado permanece intacto"

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

run_no_legacy_test() {
    local tmp home
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    mkdir -p "$home"

    HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" migrate-state --quiet >/dev/null 2>&1
    assert_equals "$?" "0" "migrate-state sem legado nao falha"

    rm -rf "$tmp"
}

run_migrate_alias_test() {
    local tmp home legacy target
    tmp="$(mktemp -d -t a11yctl-bash-test-XXXXXX)"
    home="$tmp/home"
    legacy="$home/.emacs-a11y-vm"
    target="$home/.a11yctl"

    mkdir -p "$legacy" "$target"
    printf 'legacy-disk\n' > "$legacy/debian-a11ydevs.qcow2"

    HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/a11yctl" migrate --quiet >/dev/null 2>&1
    assert_equals "$?" "0" "alias migrate retorna sucesso"
    assert_file_exists "$target/debian-a11ydevs.qcow2" "alias migrate copia estado legado"

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

run_migrate_conflict_test
run_wrapper_test
run_no_legacy_test
run_migrate_alias_test
run_unknown_command_test
run_wrapper_invalid_command_test
run_self_update_force_mock_test

printf '\nResumo: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

exit 0
