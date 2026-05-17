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

run_migrate_conflict_test
run_wrapper_test
run_no_legacy_test
run_migrate_alias_test
run_unknown_command_test
run_wrapper_invalid_command_test

printf '\nResumo: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

exit 0
