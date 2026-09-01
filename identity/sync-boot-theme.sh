#!/usr/bin/env bash
set -Eeuo pipefail

readonly USER_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly DYNAMIC_LOGO="$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg"
readonly LIVE_PALETTE="$USER_DATA_HOME/kaleidash-os/palette.toml"
readonly SYNC_HELPER="/usr/local/libexec/kaleidash-plymouth-sync"

if [[ $EUID -eq 0 ]]; then
  printf 'Run this command as your normal desktop user. It invokes sudo itself.\n' >&2
  exit 1
fi

if [[ ! -x "$SYNC_HELPER" ]]; then
  printf 'KaleidashOS Plymouth helper is not installed. Rerun ./identity/install.sh first.\n' >&2
  exit 1
fi

sudo env \
  KALEIDASH_USER_PALETTE="$LIVE_PALETTE" \
  KALEIDASH_USER_LOGO="$DYNAMIC_LOGO" \
  "$SYNC_HELPER" "$DYNAMIC_LOGO"
printf 'KaleidashOS: forced a refresh of the palette used on the next boot.\n'
