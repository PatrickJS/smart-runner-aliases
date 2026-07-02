#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/smart-rn-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

bindir="$tmpdir/bin"
mkdir -p "$bindir"

for tool in bun pnpm npm deno uv poetry pdm; do
  cat > "$bindir/$tool" <<'MOCK'
#!/usr/bin/env sh
printf '%s' "${0##*/}"
for arg in "$@"; do
  printf ' %s' "$arg"
done
printf '\n'
MOCK
  chmod +x "$bindir/$tool"
done

make_project() {
  mkdir -p "$tmpdir/$1"
  mkdir -p "$tmpdir/$1/.git"
}

expect() {
  local shell_bin=$1
  local label=$2
  local dir=$3
  local command_text=$4
  local expected=$5
  local output
  local shell_name

  shell_name=${shell_bin##*/}

  set +e
  if [ "$shell_name" = zsh ]; then
    output=$(PATH="$bindir:$PATH" "$shell_bin" -f -c ". '$repo_dir/smart-rn.sh'; cd '$dir'; $command_text" 2>&1)
  else
    output=$(PATH="$bindir:$PATH" "$shell_bin" -c ". '$repo_dir/smart-rn.sh'; cd '$dir'; $command_text" 2>&1)
  fi
  set -e

  if [ "$output" != "$expected" ]; then
    printf 'FAIL %s\n  command: %s\n  expected: %s\n  actual:   %s\n' "$label" "$command_text" "$expected" "$output" >&2
    return 1
  fi
  printf 'PASS %s -> %s\n' "$label" "$output"
}

make_project bun-project
: > "$tmpdir/bun-project/bun.lockb"
: > "$tmpdir/bun-project/package-lock.json"

make_project pnpm-project
: > "$tmpdir/pnpm-project/pnpm-lock.yaml"
mkdir -p "$tmpdir/pnpm-project/frontend"

make_project npm-project
: > "$tmpdir/npm-project/package-lock.json"

make_project deno-project
: > "$tmpdir/deno-project/deno.json"

make_project deno-with-pnpm-lock
: > "$tmpdir/deno-with-pnpm-lock/deno.json"
: > "$tmpdir/deno-with-pnpm-lock/pnpm-lock.yaml"

make_project deno-package-manager
cat > "$tmpdir/deno-package-manager/package.json" <<'PACKAGE'
{"packageManager":"deno@2.4.0"}
PACKAGE

make_project uv-project
: > "$tmpdir/uv-project/uv.lock"

make_project poetry-project
: > "$tmpdir/poetry-project/poetry.lock"

make_project pdm-project
: > "$tmpdir/pdm-project/pdm.lock"

make_project pyproject-pdm
cat > "$tmpdir/pyproject-pdm/pyproject.toml" <<'PYPROJECT'
[project]
name = "pyproject-pdm"

[tool.pdm]
distribution = false
PYPROJECT

make_project requirements-only
: > "$tmpdir/requirements-only/requirements.txt"

mkdir -p "$tmpdir/parent-lock/child"
mkdir -p "$tmpdir/parent-lock/child/.git"
: > "$tmpdir/parent-lock/package-lock.json"
cat > "$tmpdir/parent-lock/child/package.json" <<'PACKAGE'
{"packageManager":"pnpm@10.20.0"}
PACKAGE

for shell_bin in /bin/bash /bin/zsh; do
  shell_name=${shell_bin##*/}
  "$shell_bin" -n "$repo_dir/smart-rn.sh"

  expect "$shell_bin" "$shell_name bun r" "$tmpdir/bun-project" "r test" "bun run test"
  expect "$shell_bin" "$shell_name bun n i" "$tmpdir/bun-project" "n i" "bun install"
  expect "$shell_bin" "$shell_name pnpm r" "$tmpdir/pnpm-project" "r test" "pnpm run test"
  expect "$shell_bin" "$shell_name pnpm nested" "$tmpdir/pnpm-project/frontend" "r build" "pnpm run build"
  expect "$shell_bin" "$shell_name npm r" "$tmpdir/npm-project" "r test" "npm run test"
  expect "$shell_bin" "$shell_name npm n i" "$tmpdir/npm-project" "n i" "npm install"
  expect "$shell_bin" "$shell_name deno r" "$tmpdir/deno-project" "r test" "deno task test"
  expect "$shell_bin" "$shell_name deno beats pnpm lock" "$tmpdir/deno-with-pnpm-lock" "r dev" "deno task dev"
  expect "$shell_bin" "$shell_name deno packageManager profile" "$tmpdir/deno-package-manager" "r test" "deno task test"
  expect "$shell_bin" "$shell_name deno guard" "$tmpdir/deno-project" "n i" "smart-rn: 'install' is npm-style; use deno add/cache/task directly in Deno projects"
  expect "$shell_bin" "$shell_name uv r" "$tmpdir/uv-project" "r pytest" "uv run pytest"
  expect "$shell_bin" "$shell_name uv sync" "$tmpdir/uv-project" "n i" "uv sync"
  expect "$shell_bin" "$shell_name uv add" "$tmpdir/uv-project" "n i requests" "uv add requests"
  expect "$shell_bin" "$shell_name uv ci" "$tmpdir/uv-project" "n ci" "uv sync --frozen"
  expect "$shell_bin" "$shell_name poetry r" "$tmpdir/poetry-project" "r pytest" "poetry run pytest"
  expect "$shell_bin" "$shell_name poetry add" "$tmpdir/poetry-project" "n install requests" "poetry add requests"
  expect "$shell_bin" "$shell_name poetry ci" "$tmpdir/poetry-project" "n ci" "poetry check --lock"$'\n'"poetry sync"
  expect "$shell_bin" "$shell_name pdm r" "$tmpdir/pdm-project" "r pytest" "pdm run pytest"
  expect "$shell_bin" "$shell_name pdm add" "$tmpdir/pdm-project" "n add requests" "pdm add requests"
  expect "$shell_bin" "$shell_name pdm ci" "$tmpdir/pdm-project" "n ci" "pdm lock --check"$'\n'"pdm install --frozen-lockfile"
  expect "$shell_bin" "$shell_name pyproject fallback" "$tmpdir/pyproject-pdm" "r pytest" "pdm run pytest"
  expect "$shell_bin" "$shell_name requirements unsupported" "$tmpdir/requirements-only" "r test" "smart-rn: found requirements.txt but no supported Python manager lockfile/config; use python/pip/venv directly or adopt uv, Poetry, or PDM"
  expect "$shell_bin" "$shell_name git boundary" "$tmpdir/parent-lock/child" "r test" "pnpm run test"
done
