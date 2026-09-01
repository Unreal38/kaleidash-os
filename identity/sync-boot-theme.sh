#!/usr/bin/env bash
set -Eeuo pipefail

readonly USER_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly DYNAMIC_LOGO="$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg"
readonly SYNC_HELPER="/usr/local/libexec/kaleidash-plymouth-sync"

if [[ $EUID -eq 0 ]]; then
  printf 'Run this command as your normal desktop user. It invokes sudo itself.\n' >&2
  exit 1
fi

if [[ ! -x "$SYNC_HELPER" ]]; then
  printf 'KaleidashOS Plymouth helper is not installed. Rerun ./identity/install.sh first.\n' >&2
  exit 1
fi

sudo "$SYNC_HELPER" "$DYNAMIC_LOGO"
printf 'KaleidashOS: the current Noctalia palette will be used on the next boot.\n'
