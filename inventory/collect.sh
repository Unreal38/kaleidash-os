#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly VENDOR_RELEASE="/usr/lib/os-release"

output_dir="$SCRIPT_DIR"
staging_dir=""

log() {
  printf '\033[1;35mKaleidashOS inventory\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mKaleidashOS inventory warning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mKaleidashOS inventory error:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./inventory/collect.sh [--output DIRECTORY]

Collect a deterministic, privacy-conscious Fedora desktop inventory. The
default output directory is inventory/ in this repository.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output requires a directory"
      output_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ $EUID -eq 0 ]]; then
  die "run this collector as the normal desktop user, not root"
fi

[[ -r "$VENDOR_RELEASE" ]] || die "cannot read Fedora vendor identity at $VENDOR_RELEASE"

# shellcheck disable=SC1090
source "$VENDOR_RELEASE"
if [[ "${ID:-}" != "fedora" && " ${ID_LIKE:-} " != *" fedora "* ]]; then
  die "this collector currently supports Fedora-derived systems only"
fi

for command_name in awk dnf grep install mktemp python3 sed sort systemctl uname wc; do
  command -v "$command_name" >/dev/null || die "required command is missing: $command_name"
done

mkdir -p -- "$output_dir"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/kaleidash-inventory.XXXXXX")"

cleanup() {
  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi
}
trap cleanup EXIT

mkdir -p -- \
  "$staging_dir/packages" \
  "$staging_dir/repositories" \
  "$staging_dir/services" \
  "$staging_dir/system"

log "Reading explicitly installed RPM packages"
dnf -q repoquery --installed --userinstalled --queryformat '%{name}\n' \
  | sed '/^[[:space:]]*$/d' \
  | sort -u > "$staging_dir/packages/dnf-userinstalled.txt"

dnf -q repoquery --installed --userinstalled \
  --queryformat '%{name}\t%{evr}\t%{arch}\t%{reason}\t%{from_repo}\n' \
  | sed '/^[[:space:]]*$/d' \
  | sort -u > "$staging_dir/packages/dnf-reference.tsv"

log "Reading enabled DNF repositories"
dnf -q repo list --enabled --json \
  | python3 -c '
import json
import sys

repositories = json.load(sys.stdin)
for repository in sorted(repositories, key=lambda item: item["id"]):
    identifier = repository["id"].replace("\t", " ").replace("\n", " ")
    name = repository.get("name", "").replace("\t", " ").replace("\n", " ")
    print(f"{identifier}\t{name}")
' > "$staging_dir/repositories/dnf-enabled.tsv"

: > "$staging_dir/packages/flatpak-apps.tsv"
: > "$staging_dir/repositories/flatpak-remotes.tsv"

collect_flatpak_scope() {
  local scope="$1"
  local apps_raw="$staging_dir/flatpak-$scope-apps.raw"
  local remotes_raw="$staging_dir/flatpak-$scope-remotes.raw"

  if ! flatpak "--$scope" list --app \
    --columns=application,origin,branch,version > "$apps_raw"; then
    warn "could not read $scope Flatpak applications"
    return
  fi
  if ! flatpak "--$scope" remotes --columns=name,url > "$remotes_raw"; then
    warn "could not read $scope Flatpak remotes"
    return
  fi

  python3 - "$scope" "$apps_raw" "$remotes_raw" \
    "$staging_dir/packages/flatpak-apps.tsv" \
    "$staging_dir/repositories/flatpak-remotes.tsv" <<'PY'
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

scope, apps_input, remotes_input, apps_output, remotes_output = sys.argv[1:]

def rows(path: str):
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    for line in lines[1:]:
        if line.strip():
            yield [field.strip() for field in line.split("\t")]

with Path(apps_output).open("a", encoding="utf-8") as stream:
    for fields in rows(apps_input):
        fields += [""] * (4 - len(fields))
        clean = [field.replace("\n", " ").replace("\t", " ") for field in fields[:4]]
        stream.write("\t".join([scope, *clean]) + "\n")

with Path(remotes_output).open("a", encoding="utf-8") as stream:
    for fields in rows(remotes_input):
        fields += [""] * (2 - len(fields))
        name, url = fields[:2]
        parts = urlsplit(url)
        if parts.scheme == "file":
            safe_url = "redacted://local-flatpak-remote"
        else:
            netloc = parts.netloc.rsplit("@", 1)[-1]
            safe_url = urlunsplit((parts.scheme, netloc, parts.path, "", ""))
        stream.write(f"{scope}\t{name}\t{safe_url}\n")
PY
}

if command -v flatpak >/dev/null; then
  log "Reading Flatpak applications and remotes"
  collect_flatpak_scope system
  collect_flatpak_scope user
fi

sort -u -o "$staging_dir/packages/flatpak-apps.tsv" \
  "$staging_dir/packages/flatpak-apps.tsv"
sort -u -o "$staging_dir/repositories/flatpak-remotes.tsv" \
  "$staging_dir/repositories/flatpak-remotes.tsv"

log "Reading enabled systemd units"
systemctl list-unit-files --state=enabled --no-legend --no-pager \
  | awk 'NF { print $1 }' \
  | sort -u > "$staging_dir/services/system-enabled.txt"

if systemctl --user list-unit-files --state=enabled --no-legend --no-pager \
  | awk 'NF { print $1 }' \
  | sort -u > "$staging_dir/services/user-enabled.txt"; then
  :
else
  warn "the user systemd manager was unavailable; user-enabled.txt is empty"
  : > "$staging_dir/services/user-enabled.txt"
fi

log "Recording Fedora vendor identity"
{
  printf 'ID=%q\n' "${ID:-}"
  printf 'VERSION_ID=%q\n' "${VERSION_ID:-}"
  printf 'VARIANT_ID=%q\n' "${VARIANT_ID:-}"
  printf 'PLATFORM_ID=%q\n' "${PLATFORM_ID:-}"
  printf 'ARCH=%q\n' "$(uname -m)"
} > "$staging_dir/system/base.env"

capture_version() {
  local label="$1"
  local executable="$2"
  shift 2
  local value

  command -v "$executable" >/dev/null || return 0
  value="$("$executable" "$@" 2>&1 | sed -n '1p')" || return 0
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  [[ -n "$value" ]] && printf '%s\t%s\n' "$label" "$value"
}

{
  capture_version dnf dnf --version
  capture_version flatpak flatpak --version
  capture_version niri niri --version
  capture_version noctalia noctalia --version
  capture_version kitty kitty --version
  capture_version fish fish --version
  capture_version starship starship --version
  capture_version fastfetch fastfetch --version
  capture_version yazi yazi --version
} | sort -u > "$staging_dir/system/component-versions.tsv"

log "Validating captured data"
data_files=(
  packages/dnf-userinstalled.txt
  packages/dnf-reference.tsv
  packages/flatpak-apps.tsv
  repositories/dnf-enabled.tsv
  repositories/flatpak-remotes.tsv
  services/system-enabled.txt
  services/user-enabled.txt
  system/base.env
  system/component-versions.tsv
)

for relative_path in "${data_files[@]}"; do
  [[ -f "$staging_dir/$relative_path" ]] || die "collector did not produce $relative_path"
done

if grep -ERn \
  '(/home/|BEGIN [A-Z ]*PRIVATE KEY|([?&]|[[:space:]])(token|password|secret|api[_-]?key)=|://[^/@[:space:]]+@)' \
  "$staging_dir/packages" "$staging_dir/repositories" \
  "$staging_dir/services" "$staging_dir/system"; then
  die "privacy validation found a path or credential-like value; no inventory was written"
fi

for relative_path in "${data_files[@]}"; do
  install -D -m 0644 "$staging_dir/$relative_path" "$output_dir/$relative_path"
done

log "Capture complete"
printf '  RPM package intents: %s\n' "$(wc -l < "$output_dir/packages/dnf-userinstalled.txt")"
printf '  Flatpak applications: %s\n' "$(wc -l < "$output_dir/packages/flatpak-apps.tsv")"
printf '  Enabled DNF repositories: %s\n' "$(wc -l < "$output_dir/repositories/dnf-enabled.tsv")"
printf '  Enabled system units: %s\n' "$(wc -l < "$output_dir/services/system-enabled.txt")"
printf '  Enabled user units: %s\n' "$(wc -l < "$output_dir/services/user-enabled.txt")"
printf '\nReview the generated files before committing them.\n'
