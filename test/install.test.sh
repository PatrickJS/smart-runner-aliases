#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/smart-rn-install-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

home_dir="$tmpdir/home"
target_file="$home_dir/.smart-rn.sh"
mkdir -p "$home_dir"

assert_file_contains() {
  local file=$1
  local text=$2

  if ! grep -Fqx "$text" "$file"; then
    printf 'FAIL expected %s to contain line: %s\n' "$file" "$text" >&2
    printf '%s\n' '--- file contents ---' >&2
    cat "$file" >&2
    return 1
  fi
}

assert_file_not_contains() {
  local file=$1
  local text=$2

  if [ -f "$file" ] && grep -Fqx "$text" "$file"; then
    printf 'FAIL expected %s not to contain line: %s\n' "$file" "$text" >&2
    printf '%s\n' '--- file contents ---' >&2
    cat "$file" >&2
    return 1
  fi
}

count_line() {
  local file=$1
  local text=$2

  grep -Fxc "$text" "$file" 2>/dev/null || true
}

run_install() {
  HOME="$home_dir" SHELL=/bin/zsh "$repo_dir/install.sh" --target "$target_file" "$@" >/dev/null
}

start_marker='# >>> smart-runner-aliases >>>'
end_marker='# <<< smart-runner-aliases <<<'
source_line='[ -f "$HOME/.smart-rn.sh" ] && . "$HOME/.smart-rn.sh"'

run_install --shell both

[ -f "$target_file" ]
assert_file_contains "$home_dir/.zshrc" "$start_marker"
assert_file_contains "$home_dir/.zshrc" "$source_line"
assert_file_contains "$home_dir/.zshrc" "$end_marker"
assert_file_contains "$home_dir/.bashrc" "$start_marker"
assert_file_contains "$home_dir/.bashrc" "$source_line"
assert_file_contains "$home_dir/.bashrc" "$end_marker"

run_install --shell both

[ "$(count_line "$home_dir/.zshrc" "$start_marker")" = 1 ]
[ "$(count_line "$home_dir/.bashrc" "$start_marker")" = 1 ]

run_install --remove --shell zsh

assert_file_not_contains "$home_dir/.zshrc" "$start_marker"
assert_file_not_contains "$home_dir/.zshrc" "$source_line"
assert_file_not_contains "$home_dir/.zshrc" "$end_marker"
assert_file_contains "$home_dir/.bashrc" "$start_marker"

run_install --remove --shell both --delete-target

assert_file_not_contains "$home_dir/.bashrc" "$start_marker"
[ ! -f "$target_file" ]

custom_rc="$home_dir/custom.rc"
run_install --shell none --rc "$custom_rc"

assert_file_contains "$custom_rc" "$start_marker"
assert_file_contains "$custom_rc" "$source_line"
assert_file_contains "$custom_rc" "$end_marker"

printf '%s\n' 'PASS install managed add/remove'

