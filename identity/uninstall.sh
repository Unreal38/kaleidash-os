#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_STATE_DIR="/var/lib/kaleidash-os"
readonly SYSTEM_BACKUP_DIR="$SYSTEM_STATE_DIR/backups"
readonly USER_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly USER_BACKUP_DIR="$USER_STATE_HOME/kaleidash-os/backups"
readonly USER_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly USER_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly GRUB_THEME_DIR="/boot/grub2/themes/kaleidash"
readonly PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/kaleidash"

log() {
  printf '\033[1;35mKaleidashOS\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31mKaleidashOS error:\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ $EUID -eq 0 ]]; then
  die "Run this uninstaller as the desktop user that installed the identity."
fi

sudo -v

restore_system_file() {
  local path="$1"
  local key="$2"
  local state="$SYSTEM_BACKUP_DIR/$key.state"
  local data="$SYSTEM_BACKUP_DIR/$key.data"
  local link="$SYSTEM_BACKUP_DIR/$key.link"
  local kind

  sudo test -f "$state" || return
  kind="$(sudo cat "$state")"
  sudo rm -f -- "$path"

  case "$kind" in
    symlink)
      sudo ln -s "$(sudo cat "$link")" "$path"
      ;;
    file)
      sudo cp -a "$data" "$path"
      ;;
    absent)
      ;;
    *)
      die "Unknown backup state for $path"
      ;;
  esac
}

restore_user_file() {
  local path="$1"
  local key="$2"
  local state="$USER_BACKUP_DIR/$key.state"
  local data="$USER_BACKUP_DIR/$key.data"
  local link="$USER_BACKUP_DIR/$key.link"
  local kind

  [[ -f "$state" ]] || return
  kind="$(cat "$state")"
  rm -f -- "$path"

  case "$kind" in
    symlink)
      ln -s "$(cat "$link")" "$path"
      ;;
    file)
      cp -a "$data" "$path"
      ;;
    absent)
      ;;
    *)
      die "Unknown user backup state for $path"
      ;;
  esac
}

log "Restoring Fedora system identity"
sudo systemctl disable --now kaleidash-greeter-brand.service >/dev/null 2>&1 || true
restore_system_file /etc/os-release os-release
restore_system_file /etc/lsb-release lsb-release
restore_system_file /etc/issue issue
restore_system_file /etc/issue.net issue-net
restore_system_file /etc/default/grub grub-default
restore_system_file /var/lib/noctalia-greeter/greeter.toml greeter-config

index=0
while sudo test -f "$SYSTEM_STATE_DIR/greeter-logo-$index.path"; do
  logo_path="$(sudo cat "$SYSTEM_STATE_DIR/greeter-logo-$index.path")"
  restore_system_file "$logo_path" "greeter-logo-$index"
  index=$((index + 1))
done

previous_plymouth=""
if sudo test -f "$SYSTEM_STATE_DIR/plymouth-previous-theme"; then
  previous_plymouth="$(sudo cat "$SYSTEM_STATE_DIR/plymouth-previous-theme")"
fi
if [[ -n "$previous_plymouth" ]] && command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme "$previous_plymouth" -R
fi

sudo rm -f -- \
  /usr/share/icons/hicolor/scalable/apps/kaleidash.svg \
  /usr/share/pixmaps/kaleidash.svg \
  /usr/share/applications/kaleidash-about.desktop \
  /usr/local/share/kaleidash-os/kaleidash-mark-mono.svg \
  /usr/local/libexec/kaleidash-greeter-brand \
  /etc/systemd/system/kaleidash-greeter-brand.service
sudo systemctl daemon-reload
sudo rm -rf -- "$GRUB_THEME_DIR" "$PLYMOUTH_THEME_DIR"

if command -v grub2-mkconfig >/dev/null 2>&1; then
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
fi

log "Restoring user configuration"
restore_user_file "$USER_CONFIG_HOME/fish/functions/fastfetch.fish" fish-fastfetch
restore_user_file "$USER_CONFIG_HOME/noctalia/kaleidash-identity.toml" noctalia-identity-config
restore_user_file "$USER_CONFIG_HOME/noctalia/templates/kaleidash-mark-dynamic.svg.in" noctalia-logo-template
restore_user_file "$HOME/.local/bin/kaleidash-render-logo" render-logo-helper
rm -f -- \
  "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg" \
  "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.png"
rmdir -- "$USER_DATA_HOME/kaleidash-os" 2>/dev/null || true

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  sudo gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

log "Fedora branding restored. Reboot to see the restored boot and login identity."
