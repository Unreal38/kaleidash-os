#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly BIN_DIR="$HOME/.local/bin"
readonly TARGET_CONFIG="$CONFIG_HOME/noctalia/kaleidash-lockscreen.toml"
readonly TARGET_COMMAND="$BIN_DIR/kaleidash-lock"
readonly LOGO_PATH="$DATA_HOME/kaleidash-os/kaleidash-mark.svg"
readonly BACKUP_DIR="$STATE_HOME/kaleidash-os/backups/lockscreen"

log() {
  printf '\033[1;35mKaleidashOS\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mKaleidashOS warning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mKaleidashOS error:\033[0m %s\n' "$*" >&2
  exit 1
}

backup_file() {
  local path="$1"
  local key="$2"
  local state="$BACKUP_DIR/$key.state"
  local data="$BACKUP_DIR/$key.data"

  [[ -e "$state" ]] && return
  if [[ -e "$path" || -L "$path" ]]; then
    cp -a -- "$path" "$data"
    printf 'file\n' > "$state"
  else
    printf 'absent\n' > "$state"
  fi
}

[[ $EUID -ne 0 ]] || die "run this installer as your normal desktop user"
for command_name in niri noctalia python3; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is missing: $command_name"
done
[[ -f "$LOGO_PATH" ]] || die "dynamic logo is missing; run ./identity/install.sh first"

install -d -m 0755 "$CONFIG_HOME/noctalia" "$BIN_DIR" "$BACKUP_DIR"
backup_file "$TARGET_CONFIG" config
backup_file "$TARGET_COMMAND" command

outputs="$(mktemp)"
generated="$(mktemp)"
previous_config="$(mktemp)"
had_previous_config=false
trap 'rm -f -- "$outputs" "$generated" "$previous_config"' EXIT

if [[ -e "$TARGET_CONFIG" || -L "$TARGET_CONFIG" ]]; then
  cp -a -- "$TARGET_CONFIG" "$previous_config"
  had_previous_config=true
fi

log "Reading connected Niri outputs"
niri msg --json outputs > "$outputs" || die "Niri did not return its output layout"
"$SCRIPT_DIR/generate-config" "$outputs" "$LOGO_PATH" "$generated"

log "Installing the wallpaper-reactive Noctalia lock screen"
install -m 0644 "$generated" "$TARGET_CONFIG"
install -m 0755 "$SCRIPT_DIR/kaleidash-lock" "$TARGET_COMMAND"

if ! noctalia config validate >/dev/null; then
  if [[ $had_previous_config == true ]]; then
    cp -a -- "$previous_config" "$TARGET_CONFIG"
  else
    rm -f -- "$TARGET_CONFIG"
  fi
  noctalia config validate || true
  die "Noctalia rejected the generated configuration; the previous lock-screen file was restored"
fi
if ! noctalia msg config-reload >/dev/null; then
  warn "Noctalia is not responding; the lock-screen config will load at the next shell start."
fi

log "Lock-screen installation complete"
printf 'Test it now with: kaleidash-lock\n'
printf 'Restore the previous files with: %s/uninstall.sh\n' "$SCRIPT_DIR"
