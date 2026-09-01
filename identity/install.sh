#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly SYSTEM_STATE_DIR="/var/lib/kaleidash-os"
readonly SYSTEM_BACKUP_DIR="$SYSTEM_STATE_DIR/backups"
readonly USER_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly USER_STATE_DIR="$USER_STATE_HOME/kaleidash-os"
readonly USER_BACKUP_DIR="$USER_STATE_DIR/backups"
readonly USER_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly USER_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly GRUB_THEME_DIR="/boot/grub2/themes/kaleidash"
readonly PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/kaleidash"

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

if [[ $EUID -eq 0 ]]; then
  die "Run this installer as your normal desktop user. It invokes sudo only for system files."
fi

[[ -f "$REPO_ROOT/brand/logo/kaleidash-mark.svg" ]] || die "Run this script from a complete KaleidashOS repository checkout."
[[ -r /usr/lib/os-release ]] || die "Cannot read Fedora's vendor os-release file."

# shellcheck disable=SC1091
source /usr/lib/os-release
if [[ "${ID:-}" != "fedora" && " ${ID_LIKE:-} " != *" fedora "* ]]; then
  die "This identity installer currently supports Fedora-derived systems only."
fi

readonly FEDORA_VERSION_ID="${VERSION_ID:-unknown}"

sudo -v
sudo install -d -m 0755 "$SYSTEM_STATE_DIR" "$SYSTEM_BACKUP_DIR"
install -d -m 0755 "$USER_STATE_DIR" "$USER_BACKUP_DIR"

backup_system_file() {
  local path="$1"
  local key="$2"
  local state="$SYSTEM_BACKUP_DIR/$key.state"
  local data="$SYSTEM_BACKUP_DIR/$key.data"
  local link="$SYSTEM_BACKUP_DIR/$key.link"

  if sudo test -e "$state"; then
    return
  fi

  if sudo test -L "$path"; then
    sudo readlink "$path" | sudo tee "$link" >/dev/null
    sudo cp -L --preserve=mode,timestamps "$path" "$data"
    printf 'symlink\n' | sudo tee "$state" >/dev/null
  elif sudo test -e "$path"; then
    sudo cp -a "$path" "$data"
    printf 'file\n' | sudo tee "$state" >/dev/null
  else
    printf 'absent\n' | sudo tee "$state" >/dev/null
  fi
}

backup_user_file() {
  local path="$1"
  local key="$2"
  local state="$USER_BACKUP_DIR/$key.state"
  local data="$USER_BACKUP_DIR/$key.data"
  local link="$USER_BACKUP_DIR/$key.link"

  [[ -e "$state" ]] && return

  if [[ -L "$path" ]]; then
    readlink "$path" > "$link"
    cp -L --preserve=mode,timestamps "$path" "$data"
    printf 'symlink\n' > "$state"
  elif [[ -e "$path" ]]; then
    cp -a "$path" "$data"
    printf 'file\n' > "$state"
  else
    printf 'absent\n' > "$state"
  fi
}

write_os_release() {
  local generated
  generated="$(mktemp)"

  "$SCRIPT_DIR/system/generate-os-release" /usr/lib/os-release "$generated" "$FEDORA_VERSION_ID"

  backup_system_file /etc/os-release os-release
  sudo install -m 0644 "$generated" /etc/os-release.kaleidash-new
  sudo mv -fT -- /etc/os-release.kaleidash-new /etc/os-release
  rm -f -- "$generated"
}

install_prerequisites() {
  log "Installing identity prerequisites"
  sudo dnf -y install plymouth-theme-spinner librsvg2-tools >/dev/null
}

write_text_identity() {
  local generated
  generated="$(mktemp)"

  backup_system_file /etc/lsb-release lsb-release
  cat > "$generated" <<EOF
DISTRIB_ID=KaleidashOS
DISTRIB_RELEASE=$FEDORA_VERSION_ID
DISTRIB_CODENAME=
DISTRIB_DESCRIPTION="KaleidashOS $FEDORA_VERSION_ID (Fedora-based)"
EOF
  sudo install -m 0644 "$generated" /etc/lsb-release

  backup_system_file /etc/issue issue
  cat > "$generated" <<EOF
KaleidashOS $FEDORA_VERSION_ID (Fedora-based) \\n \\l
EOF
  sudo install -m 0644 "$generated" /etc/issue

  backup_system_file /etc/issue.net issue-net
  printf 'KaleidashOS %s (Fedora-based)\n' "$FEDORA_VERSION_ID" > "$generated"
  sudo install -m 0644 "$generated" /etc/issue.net

  rm -f -- "$generated"
}

install_desktop_identity() {
  log "Installing system icons and desktop identity"
  sudo install -D -m 0644 "$REPO_ROOT/brand/logo/kaleidash-mark.svg" \
    /usr/share/icons/hicolor/scalable/apps/kaleidash.svg
  sudo install -D -m 0644 "$REPO_ROOT/brand/logo/kaleidash-mark.svg" \
    /usr/share/pixmaps/kaleidash.svg
  sudo install -D -m 0644 "$SCRIPT_DIR/desktop/kaleidash-about.desktop" \
    /usr/share/applications/kaleidash-about.desktop
  sudo install -D -m 0644 "$REPO_ROOT/brand/logo/kaleidash-mark.svg" \
    /usr/local/share/kaleidash-os/kaleidash-mark.svg
  sudo install -m 0644 "$SCRIPT_DIR/assets/kaleidash-mark-dynamic.svg.in" \
    /usr/local/share/kaleidash-os/kaleidash-mark-dynamic.svg.in

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
  fi
}

install_user_identity() {
  local fish_function="$USER_CONFIG_HOME/fish/functions/fastfetch.fish"
  local noctalia_config="$USER_CONFIG_HOME/noctalia/kaleidash-identity.toml"
  local noctalia_template="$USER_CONFIG_HOME/noctalia/templates/kaleidash-mark-dynamic.svg.in"
  local generated

  log "Installing wallpaper-reactive terminal identity"
  install -d -m 0755 \
    "$USER_DATA_HOME/kaleidash-os" \
    "$USER_CONFIG_HOME/fish/functions" \
    "$USER_CONFIG_HOME/noctalia/templates" \
    "$USER_BIN_DIR"

  backup_user_file "$fish_function" fish-fastfetch
  backup_user_file "$noctalia_config" noctalia-identity-config
  backup_user_file "$noctalia_template" noctalia-logo-template
  backup_user_file "$USER_BIN_DIR/kaleidash-render-logo" render-logo-helper

  if [[ ! -f "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.png" ]]; then
    install -m 0644 "$REPO_ROOT/brand/logo/kaleidash-mark-compact.png" \
      "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.png"
  fi
  if [[ ! -f "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg" ]]; then
    install -m 0644 "$REPO_ROOT/brand/logo/kaleidash-mark-compact.svg" \
      "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg"
  fi
  install -m 0644 "$SCRIPT_DIR/user/fastfetch.fish" "$fish_function"
  generated="$(mktemp)"
  python3 - "$SCRIPT_DIR/noctalia/kaleidash-identity.toml" "$generated" \
    "$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg" <<'PY'
import json
import sys
from pathlib import Path

source, output, logo_path = sys.argv[1:]
config = Path(source).read_text(encoding="utf-8")
config = config.replace("@KALEIDASH_LOGO_PATH@", json.dumps(logo_path))
Path(output).write_text(config, encoding="utf-8")
PY
  install -m 0644 "$generated" "$noctalia_config"
  rm -f -- "$generated"
  install -m 0644 "$SCRIPT_DIR/assets/kaleidash-mark-dynamic.svg.in" "$noctalia_template"
  install -m 0755 "$SCRIPT_DIR/user/kaleidash-render-logo" "$USER_BIN_DIR/kaleidash-render-logo"

  if command -v noctalia >/dev/null 2>&1; then
    if ! noctalia config validate >/dev/null; then
      warn "Noctalia reported a configuration error. Run 'noctalia config validate' for details."
    fi
  fi
}

set_toml_boolean() {
  local input="$1"
  local output="$2"
  local section="$3"
  local key="$4"
  local value="$5"

  python3 - "$input" "$output" "$section" "$key" "$value" <<'PY'
import re
import sys

input_path, output_path, section, key, value = sys.argv[1:]
try:
    lines = open(input_path, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    lines = []

section_header = f"[{section}]"
section_start = None
section_end = len(lines)
for index, line in enumerate(lines):
    stripped = line.strip()
    if stripped == section_header:
        section_start = index
        continue
    if section_start is not None and index > section_start and re.match(r"^\s*\[", line):
        section_end = index
        break

new_line = f"{key} = {value}"
if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend([section_header, new_line])
else:
    key_pattern = re.compile(rf"^\s*{re.escape(key)}\s*=")
    for index in range(section_start + 1, section_end):
        if key_pattern.match(lines[index]):
            lines[index] = new_line
            break
    else:
        lines.insert(section_end, new_line)

open(output_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

set_toml_string() {
  local input="$1"
  local output="$2"
  local section="$3"
  local key="$4"
  local value="$5"

  python3 - "$input" "$output" "$section" "$key" "$value" <<'PY'
import json
import re
import sys

input_path, output_path, section, key, value = sys.argv[1:]
try:
    lines = open(input_path, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    lines = []

section_header = f"[{section}]"
section_start = None
section_end = len(lines)
for index, line in enumerate(lines):
    stripped = line.strip()
    if stripped == section_header:
        section_start = index
        continue
    if section_start is not None and index > section_start and re.match(r"^\s*\[", line):
        section_end = index
        break

new_line = f"{key} = {json.dumps(value)}"
if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend([section_header, new_line])
else:
    key_pattern = re.compile(rf"^\s*{re.escape(key)}\s*=")
    for index in range(section_start + 1, section_end):
        if key_pattern.match(lines[index]):
            lines[index] = new_line
            break
    else:
        lines.insert(section_end, new_line)

open(output_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

install_greeter_identity() {
  local greeter_state_dir="/var/lib/noctalia-greeter"
  local greeter_config="$greeter_state_dir/greeter.toml"
  local generated
  local index=0
  local logo_path
  local found=0

  if [[ ! -d "$greeter_state_dir" ]]; then
    warn "Noctalia Greeter state directory was not found; skipping greeter branding."
    return
  fi

  log "Branding Noctalia Greeter"
  sudo install -D -m 0755 "$SCRIPT_DIR/system/kaleidash-greeter-brand" \
    /usr/local/libexec/kaleidash-greeter-brand
  sudo install -D -m 0644 "$SCRIPT_DIR/system/kaleidash-greeter-brand.service" \
    /etc/systemd/system/kaleidash-greeter-brand.service
  sudo install -D -m 0644 "$SCRIPT_DIR/system/kaleidash-greeter-brand.path" \
    /etc/systemd/system/kaleidash-greeter-brand.path
  sudo systemctl daemon-reload
  sudo systemctl enable kaleidash-greeter-brand.service kaleidash-greeter-brand.path >/dev/null

  backup_system_file "$greeter_config" greeter-config
  generated="$(mktemp)"
  if sudo test -f "$greeter_config"; then
    sudo cat "$greeter_config" > "$generated"
  else
    : > "$generated"
  fi
  set_toml_string "$generated" "$generated.updated" appearance scheme Synced
  mv -- "$generated.updated" "$generated"
  set_toml_boolean "$generated" "$generated.updated" appearance hide_logo false
  mv -- "$generated.updated" "$generated"

  local greeter_owner
  greeter_owner="$(stat -c '%U:%G' "$greeter_state_dir")"
  sudo install -o "${greeter_owner%%:*}" -g "${greeter_owner##*:}" -m 0644 "$generated" "$greeter_config"
  rm -f -- "$generated"

  while IFS= read -r -d '' logo_path; do
    found=1
    backup_system_file "$logo_path" "greeter-logo-$index"
    printf '%s\n' "$logo_path" | sudo tee "$SYSTEM_STATE_DIR/greeter-logo-$index.path" >/dev/null
    index=$((index + 1))
  done < <(sudo find /usr/share/noctalia-greeter /usr/local/share/noctalia-greeter \
    -name noctalia.svg -print0 2>/dev/null || true)

  if [[ $found -eq 0 ]]; then
    warn "The installed Noctalia logo asset was not found; palette sync remains configured, but the greeter logo was not replaced."
  else
    sudo systemctl start kaleidash-greeter-brand.service
  fi
  sudo systemctl start kaleidash-greeter-brand.path
}

install_plymouth_identity() {
  local previous_theme_file="$SYSTEM_STATE_DIR/plymouth-previous-theme"
  local spinner_dir="/usr/share/plymouth/themes/spinner"
  local theme_file
  local logo_source="$USER_DATA_HOME/kaleidash-os/kaleidash-mark.svg"

  log "Installing KaleidashOS Plymouth boot splash"

  if ! sudo test -e "$previous_theme_file"; then
    previous_theme="$(plymouth-set-default-theme)"
    if [[ "$previous_theme" == "kaleidash" || -z "$previous_theme" ]]; then
      previous_theme="spinner"
    fi
    printf '%s\n' "$previous_theme" | sudo tee "$previous_theme_file" >/dev/null
  fi

  sudo install -d -m 0755 "$PLYMOUTH_THEME_DIR"
  sudo cp -a "$spinner_dir/." "$PLYMOUTH_THEME_DIR/"
  sudo rm -f -- "$PLYMOUTH_THEME_DIR/spinner.plymouth"
  theme_file="$PLYMOUTH_THEME_DIR/kaleidash.plymouth"
  sudo cp "$spinner_dir/spinner.plymouth" "$theme_file"
  sudo sed -i \
    -e 's/^Name=.*/Name=KaleidashOS/' \
    -e 's/^Description=.*/Description=KaleidashOS boot splash/' \
    -e 's#^ImageDir=.*#ImageDir=/usr/share/plymouth/themes/kaleidash#' \
    "$theme_file"
  sudo install -D -m 0755 "$SCRIPT_DIR/system/kaleidash-plymouth-sync" \
    /usr/local/libexec/kaleidash-plymouth-sync

  [[ -f "$logo_source" ]] || logo_source="$REPO_ROOT/brand/logo/kaleidash-mark.svg"
  sudo /usr/local/libexec/kaleidash-plymouth-sync "$logo_source"
}

set_grub_key() {
  local file="$1"
  local key="$2"
  local value="$3"

  python3 - "$file" "$key" "$value" <<'PY'
import re
import sys

path, key, value = sys.argv[1:]
lines = open(path, encoding="utf-8").read().splitlines()
replacement = f'{key}="{value}"'
pattern = re.compile(rf"^\s*{re.escape(key)}=")
for index, line in enumerate(lines):
    if pattern.match(line):
        lines[index] = replacement
        break
else:
    lines.append(replacement)
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

install_grub_identity() {
  local generated

  if ! command -v grub2-mkconfig >/dev/null 2>&1; then
    warn "grub2-mkconfig is unavailable; skipping GRUB branding."
    return
  fi

  log "Installing KaleidashOS GRUB theme"
  backup_system_file /etc/default/grub grub-default
  backup_system_file /boot/grub2/grubenv grubenv
  generated="$(mktemp)"
  sudo cat /etc/default/grub > "$generated"
  set_grub_key "$generated" GRUB_THEME "$GRUB_THEME_DIR/theme.txt"
  set_grub_key "$generated" GRUB_GFXMODE auto
  set_grub_key "$generated" GRUB_DISTRIBUTOR KaleidashOS
  set_grub_key "$generated" GRUB_TIMEOUT_STYLE menu
  set_grub_key "$generated" GRUB_TIMEOUT 2
  sudo install -m 0644 "$generated" /etc/default/grub
  rm -f -- "$generated"

  sudo install -d -m 0755 "$GRUB_THEME_DIR"
  sudo install -m 0644 "$SCRIPT_DIR/grub/theme.txt" "$GRUB_THEME_DIR/theme.txt"
  sudo install -m 0644 "$SCRIPT_DIR/grub/background.png" "$GRUB_THEME_DIR/background.png"
  if command -v grub2-editenv >/dev/null 2>&1; then
    sudo grub2-editenv - unset menu_auto_hide
  fi
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
}

install_prerequisites
log "Applying system metadata"
write_os_release
write_text_identity
install_desktop_identity
install_user_identity
install_greeter_identity
install_plymouth_identity
install_grub_identity

log "Identity installation complete"
printf '\n'
printf 'Visible immediately: Fastfetch, hostnamectl, system information, and application launcher identity.\n'
printf 'Visible after the next wallpaper/theme application: wallpaper-colored Fastfetch logo.\n'
printf 'Visible after reboot or logout: GRUB, palette-colored Plymouth, and the synced KaleidashOS Noctalia Greeter.\n'
printf 'After a later wallpaper change, update the next boot with: %s/identity/sync-boot-theme.sh\n' "$REPO_ROOT"
printf '\n'
printf 'Reboot when convenient. Restore Fedora branding with: %s/identity/uninstall.sh\n' "$REPO_ROOT"
