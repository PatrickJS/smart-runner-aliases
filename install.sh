#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$repo_dir/smart-rn.sh"
target_file="${SMART_RN_TARGET:-$HOME/.smart-rn.sh}"
rc_file=""
edit_rc=1

usage() {
  printf '%s\n' "Usage: ./install.sh [--target FILE] [--rc FILE] [--no-rc]"
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
    --no-rc)
      edit_rc=0
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

[ -f "$source_file" ] || {
  printf '%s\n' "smart-rn: missing source file: $source_file" >&2
  exit 1
}

timestamp=$(date +%Y%m%d%H%M%S)
target_dir=$(dirname -- "$target_file")
mkdir -p "$target_dir"

if [ -f "$target_file" ]; then
  cp "$target_file" "$target_file.bak.$timestamp"
fi

cp "$source_file" "$target_file"

if [ "$edit_rc" -eq 1 ]; then
  if [ -z "$rc_file" ]; then
    case "${SHELL:-}" in
      */zsh) rc_file="$HOME/.zshrc" ;;
      */bash) rc_file="$HOME/.bashrc" ;;
      *) rc_file="$HOME/.profile" ;;
    esac
  fi

  touch "$rc_file"
  source_line='[ -f "$HOME/.smart-rn.sh" ] && . "$HOME/.smart-rn.sh"'
  if ! grep -Fqx "$source_line" "$rc_file"; then
    cp "$rc_file" "$rc_file.bak.$timestamp"
    {
      printf '\n'
      printf '%s\n' '# smart-runner-aliases'
      printf '%s\n' "$source_line"
    } >> "$rc_file"
  fi
fi

printf '%s\n' "Installed $target_file"
if [ "$edit_rc" -eq 1 ]; then
  printf '%s\n' "Shell rc updated: $rc_file"
else
  printf '%s\n' "Shell rc unchanged (--no-rc)"
fi

