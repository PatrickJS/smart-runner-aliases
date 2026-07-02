# Smart project runner aliases for bash and zsh.

unalias r n ni nc nci nb nd nt 2>/dev/null || true

__sr_has_file() {
  [ -f "$1" ]
}

__sr_has_path() {
  [ -e "$1" ]
}

__sr_manager_from_lockfiles() {
  local dir
  dir=$1

  if __sr_has_file "$dir/bun.lock" || __sr_has_file "$dir/bun.lockb"; then
    printf '%s\n' bun
    return 0
  fi
  if __sr_has_file "$dir/deno.lock" || __sr_has_file "$dir/deno.json" || __sr_has_file "$dir/deno.jsonc"; then
    printf '%s\n' deno
    return 0
  fi
  if __sr_has_file "$dir/pnpm-lock.yaml"; then
    printf '%s\n' pnpm
    return 0
  fi
  if __sr_has_file "$dir/package-lock.json" || __sr_has_file "$dir/npm-shrinkwrap.json"; then
    printf '%s\n' npm
    return 0
  fi
  if __sr_has_file "$dir/uv.lock"; then
    printf '%s\n' uv
    return 0
  fi
  if __sr_has_file "$dir/poetry.lock"; then
    printf '%s\n' poetry
    return 0
  fi
  if __sr_has_file "$dir/pdm.lock"; then
    printf '%s\n' pdm
    return 0
  fi

  return 1
}

__sr_package_manager_from_package_json() {
  local file
  file=$1

  __sr_has_file "$file" || return 1
  command -v node >/dev/null 2>&1 || return 1

  node -e '
    const fs = require("node:fs");
    try {
      const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const value = typeof pkg.packageManager === "string" ? pkg.packageManager : "";
      const manager = value.split("@")[0];
      if (["bun", "pnpm", "npm", "deno"].includes(manager)) process.stdout.write(manager);
    } catch {}
  ' "$file" 2>/dev/null
}

__sr_pyproject_manager_from_pyproject() {
  local file
  file=$1

  __sr_has_file "$file" || return 1

  awk '
    /^[[:space:]]*\[tool\.uv\][[:space:]]*$/ { print "uv"; exit }
    /^[[:space:]]*\[tool\.poetry\][[:space:]]*$/ { print "poetry"; exit }
    /^[[:space:]]*\[tool\.pdm\][[:space:]]*$/ { print "pdm"; exit }
  ' "$file"
}

__sr_detect_manager() {
  local dir parent manager fallback
  dir=${PWD:-.}
  fallback=

  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    manager=$(__sr_manager_from_lockfiles "$dir" 2>/dev/null || true)
    if [ -n "$manager" ]; then
      printf '%s\n' "$manager"
      return 0
    fi

    if [ -z "$fallback" ]; then
      manager=$(__sr_package_manager_from_package_json "$dir/package.json" 2>/dev/null || true)
      if [ -n "$manager" ]; then
        fallback=$manager
      else
        manager=$(__sr_pyproject_manager_from_pyproject "$dir/pyproject.toml" 2>/dev/null || true)
        if [ -n "$manager" ]; then
          fallback=$manager
        elif __sr_has_file "$dir/deno.json" || __sr_has_file "$dir/deno.jsonc"; then
          fallback=deno
        elif __sr_has_file "$dir/requirements.txt"; then
          fallback=python-unsupported
        fi
      fi
    fi

    if __sr_has_path "$dir/.git"; then
      break
    fi

    parent=${dir%/*}
    [ "$parent" = "$dir" ] && break
    dir=$parent
  done

  if [ -n "$fallback" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  if command -v pnpm >/dev/null 2>&1; then
    printf '%s\n' pnpm
  else
    printf '%s\n' npm
  fi
}

__sr_require_command() {
  local command_name manager_name
  command_name=$1
  manager_name=$2

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s\n' "smart-rn: detected $manager_name project, but '$command_name' is not installed or not on PATH" >&2
    return 127
  fi
}

__sr_python_unsupported() {
  printf '%s\n' "smart-rn: found requirements.txt but no supported Python manager lockfile/config; use python/pip/venv directly or adopt uv, Poetry, or PDM" >&2
  return 64
}

r() {
  local manager
  manager=$(__sr_detect_manager)

  case "$manager" in
    bun)
      __sr_require_command bun Bun || return $?
      command bun run "$@"
      ;;
    pnpm)
      __sr_require_command pnpm pnpm || return $?
      command pnpm run "$@"
      ;;
    npm)
      __sr_require_command npm npm || return $?
      command npm run "$@"
      ;;
    deno)
      __sr_require_command deno Deno || return $?
      command deno task "$@"
      ;;
    uv)
      __sr_require_command uv uv || return $?
      command uv run "$@"
      ;;
    poetry)
      __sr_require_command poetry Poetry || return $?
      command poetry run "$@"
      ;;
    pdm)
      __sr_require_command pdm PDM || return $?
      command pdm run "$@"
      ;;
    python-unsupported)
      __sr_python_unsupported
      ;;
    *)
      printf '%s\n' "smart-rn: unsupported project manager: $manager" >&2
      return 64
      ;;
  esac
}

n() {
  local manager subcommand
  manager=$(__sr_detect_manager)
  subcommand=${1:-}

  if [ "$subcommand" = i ]; then
    shift
    subcommand=install
    set -- install "$@"
  fi

  case "$manager" in
    bun)
      __sr_require_command bun Bun || return $?
      command bun "$@"
      ;;
    pnpm)
      __sr_require_command pnpm pnpm || return $?
      command pnpm "$@"
      ;;
    npm)
      __sr_require_command npm npm || return $?
      command npm "$@"
      ;;
    deno)
      __sr_require_command deno Deno || return $?
      case "$subcommand" in
        install|ci)
          printf '%s\n' "smart-rn: '$subcommand' is npm-style; use deno add/cache/task directly in Deno projects" >&2
          return 64
          ;;
        *)
          command deno "$@"
          ;;
      esac
      ;;
    uv)
      __sr_require_command uv uv || return $?
      case "$subcommand" in
        install)
          shift
          if [ "$#" -eq 0 ]; then
            command uv sync
          else
            command uv add "$@"
          fi
          ;;
        add)
          shift
          command uv add "$@"
          ;;
        ci)
          command uv sync --frozen
          ;;
        *)
          command uv "$@"
          ;;
      esac
      ;;
    poetry)
      __sr_require_command poetry Poetry || return $?
      case "$subcommand" in
        install)
          shift
          if [ "$#" -eq 0 ]; then
            command poetry sync
          else
            command poetry add "$@"
          fi
          ;;
        add)
          shift
          command poetry add "$@"
          ;;
        ci)
          command poetry check --lock && command poetry sync
          ;;
        *)
          command poetry "$@"
          ;;
      esac
      ;;
    pdm)
      __sr_require_command pdm PDM || return $?
      case "$subcommand" in
        install)
          shift
          if [ "$#" -eq 0 ]; then
            command pdm install
          else
            command pdm add "$@"
          fi
          ;;
        add)
          shift
          command pdm add "$@"
          ;;
        ci)
          command pdm lock --check && command pdm install --frozen-lockfile
          ;;
        *)
          command pdm "$@"
          ;;
      esac
      ;;
    python-unsupported)
      __sr_python_unsupported
      ;;
    *)
      printf '%s\n' "smart-rn: unsupported project manager: $manager" >&2
      return 64
      ;;
  esac
}

alias ni='n install'
alias nc='n ci'
alias nci='n ci'
alias nb='r build'
alias nd='r deploy'
alias nt='r test'

