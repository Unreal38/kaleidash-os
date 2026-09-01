#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly TARGET_CONFIG="$CONFIG_HOME/noctalia/kaleidash-lockscreen.toml"
readonly TARGET_COMMAND="$HOME/.local/bin/kaleidash-lock"
readonly BACKUP_DIR="$STATE_HOME/kaleidash-os/backups/lockscreen"

die() {
  printf '\033[1;31mKaleidashOS error:\033[0m %s\n' "$*" >&2
  exit 1
}

restore_file() {
  local path="$1"
  local key="$2"
  local state="$BACKUP_DIR/$key.state"
  local data="$BACKUP_DIR/$key.data"
  local kind

  [[ -f "$state" ]] || return
  kind="$(cat "$state")"
  rm -f -- "$path"
  case "$kind" in
    file) cp -a -- "$data" "$path" ;;
    absent) ;;
    *) die "unknown backup state for $path" ;;
  esac
}

[[ $EUID -ne 0 ]] || die "run this uninstaller as your normal desktop user"
restore_file "$TARGET_CONFIG" config
restore_file "$TARGET_COMMAND" command

if command -v noctalia >/dev/null 2>&1; then
  noctalia msg config-reload >/dev/null 2>&1 || true
fi

printf 'KaleidashOS lock-screen configuration restored.\n'
printf 'The swaylock package was not removed.\n'
