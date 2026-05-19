#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$repo_dir/smart-rn.sh"
target_file="${SMART_RN_TARGET:-$HOME/.smart-rn.sh}"
rc_file=""
edit_rc=1
shell_selection=auto
mode=add
delete_target=0
managed_start='# >>> smart-runner-aliases >>>'
managed_end='# <<< smart-runner-aliases <<<'

usage() {
  printf '%s\n' "Usage: ./install.sh [--target FILE] [--shell auto|zsh|bash|both|none] [--rc FILE] [--no-rc] [--remove] [--delete-target]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      target_file=$2
      shift 2
      ;;
    --rc)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      rc_file=$2
      shift 2
      ;;
    --shell)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      case "$2" in
        auto|zsh|bash|both|none) shell_selection=$2 ;;
        *) usage >&2; exit 64 ;;
      esac
      shift 2
      ;;
    --no-rc)
      edit_rc=0
      shift
      ;;
    --remove|--uninstall)
      mode=remove
      shift
      ;;
    --add|--install)
      mode=add
      shift
      ;;
    --delete-target)
      delete_target=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

timestamp=$(date +%Y%m%d%H%M%S)

source_path_for_rc=$target_file
case "$target_file" in
  "$HOME"/*)
    source_path_for_rc='$HOME/'"${target_file#"$HOME"/}"
    ;;
esac

source_line="[ -f \"$source_path_for_rc\" ] && . \"$source_path_for_rc\""

rc_targets() {
  if [ "$edit_rc" -ne 1 ]; then
    return 0
  fi

  if [ -n "$rc_file" ]; then
    printf '%s\n' "$rc_file"
    return 0
  fi

  case "$shell_selection" in
    zsh)
      printf '%s\n' "$HOME/.zshrc"
      ;;
    bash)
      printf '%s\n' "$HOME/.bashrc"
      ;;
    both)
      printf '%s\n' "$HOME/.zshrc"
      printf '%s\n' "$HOME/.bashrc"
      ;;
    none)
      return 0
      ;;
    auto)
      case "${SHELL:-}" in
        */zsh) printf '%s\n' "$HOME/.zshrc" ;;
        */bash) printf '%s\n' "$HOME/.bashrc" ;;
        *) printf '%s\n' "$HOME/.profile" ;;
      esac
      ;;
  esac
}

backup_file() {
  if [ -f "$1" ]; then
    cp "$1" "$1.bak.$timestamp"
  fi
}

remove_managed_block() {
  file=$1

  [ -f "$file" ] || return 0

  tmp="$file.tmp.$$"
  set +e
  awk -v start="$managed_start" -v end="$managed_end" '
    $0 == start { skip = 1; changed = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
    END {
      if (skip) exit 2
      if (!changed) exit 3
    }
  ' "$file" > "$tmp"
  status=$?
  set -e

  case "$status" in
    0)
      backup_file "$file"
      mv "$tmp" "$file"
      ;;
    2)
      rm -f "$tmp"
      printf '%s\n' "smart-rn: unterminated managed block in $file" >&2
      return 1
      ;;
    3)
      rm -f "$tmp"
      ;;
    *)
      rm -f "$tmp"
      return "$status"
      ;;
  esac
}

add_managed_block() {
  file=$1
  dir=$(dirname -- "$file")

  mkdir -p "$dir"
  touch "$file"
  remove_managed_block "$file"
  backup_file "$file"
  {
    printf '\n'
    printf '%s\n' "$managed_start"
    printf '%s\n' '# Managed by smart-runner-aliases/install.sh'
    printf '%s\n' "$source_line"
    printf '%s\n' "$managed_end"
  } >> "$file"
}

if [ "$mode" = add ]; then
  [ -f "$source_file" ] || {
    printf '%s\n' "smart-rn: missing source file: $source_file" >&2
    exit 1
  }

  target_dir=$(dirname -- "$target_file")
  mkdir -p "$target_dir"

  if [ -f "$target_file" ]; then
    cp "$target_file" "$target_file.bak.$timestamp"
  fi

  cp "$source_file" "$target_file"

  for rc_target in $(rc_targets); do
    add_managed_block "$rc_target"
  done

  printf '%s\n' "Installed $target_file"
  if [ "$edit_rc" -eq 1 ]; then
    rc_output=$(rc_targets | paste -sd ', ' -)
    if [ -n "$rc_output" ]; then
      printf '%s\n' "Shell rc updated: $rc_output"
    else
      printf '%s\n' "Shell rc unchanged"
    fi
  else
    printf '%s\n' "Shell rc unchanged (--no-rc)"
  fi
else
  for rc_target in $(rc_targets); do
    remove_managed_block "$rc_target"
  done

  if [ "$delete_target" -eq 1 ] && [ -f "$target_file" ]; then
    backup_file "$target_file"
    rm -f "$target_file"
  fi

  if [ "$delete_target" -eq 1 ]; then
    printf '%s\n' "Removed managed shell block and deleted $target_file"
  else
    printf '%s\n' "Removed managed shell block"
  fi
fi
