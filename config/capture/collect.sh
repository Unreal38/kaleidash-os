#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
readonly ALLOWLIST="$SCRIPT_DIR/allowlist.tsv"
readonly CAPTURE_HOME="${KALEIDASH_CAPTURE_HOME:-$HOME}"
readonly CAPTURE_ROOT="${KALEIDASH_CAPTURE_ROOT:-/}"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$CAPTURE_HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$CAPTURE_HOME/.local/share}"
readonly STATE_HOME="${XDG_STATE_HOME:-$CAPTURE_HOME/.local/state}"
readonly CAPTURE_USER="${KALEIDASH_CAPTURE_USER:-${USER:-}}"
readonly CAPTURE_HOSTNAME="${KALEIDASH_CAPTURE_HOSTNAME:-$(hostname)}"

output_dir="${KALEIDASH_CAPTURE_OUTPUT:-$REPO_ROOT/config/snapshot}"
staging_dir=""
replacement_dir=""
previous_dir=""
captured_count=0
skipped_count=0

log() {
  printf '\033[1;35mKaleidashOS config capture\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mKaleidashOS config capture warning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mKaleidashOS config capture error:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./config/capture/collect.sh [--output DIRECTORY]

Capture the explicitly allowlisted desktop configuration into config/snapshot.
The result is path-tokenized, privacy-validated, and ready for manual review.
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
    *) die "unknown argument: $1" ;;
  esac
done

if [[ $EUID -eq 0 && "${KALEIDASH_CAPTURE_ALLOW_ROOT:-0}" != 1 ]]; then
  die "run this collector as the normal desktop user"
fi
[[ -f "$ALLOWLIST" ]] || die "capture allowlist is missing"
for command_name in cp cut find grep hostname install mktemp mv python3 rm rmdir sha256sum sort stat; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is missing: $command_name"
done

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/kaleidash-config.XXXXXX")"
readonly SNAPSHOT="$staging_dir/snapshot"
readonly OUTPUTS_JSON="$staging_dir/outputs.json"
mkdir -p -- "$SNAPSHOT"

cleanup() {
  [[ -d "$staging_dir" ]] && rm -rf -- "$staging_dir"
  [[ -n "$replacement_dir" && -d "$replacement_dir" ]] && rm -rf -- "$replacement_dir"
  [[ -n "$previous_dir" && -d "$previous_dir" ]] && warn "previous snapshot remains at $previous_dir"
  return 0
}
trap cleanup EXIT

capture_file() {
  local source="$1"
  local destination="$2"
  local mode=0644

  if [[ -L "$source" ]]; then
    warn "skipping symbolic link: $source"
    ((skipped_count += 1))
    return
  fi
  if [[ ! -f "$source" || ! -r "$source" ]]; then
    ((skipped_count += 1))
    return
  fi
  if [[ $(stat -c '%s' -- "$source") -gt 1048576 ]]; then
    warn "skipping file larger than 1 MiB: $source"
    ((skipped_count += 1))
    return
  fi
  if [[ -s "$source" ]] && ! grep -Iq . "$source"; then
    warn "skipping non-text file: $source"
    ((skipped_count += 1))
    return
  fi
  [[ -x "$source" ]] && mode=0755
  install -D -m "$mode" -- "$source" "$SNAPSHOT/$destination"
  ((captured_count += 1))
}

capture_tree() {
  local source="$1"
  local destination="$2"
  local extensions="$3"
  local path relative extension

  [[ -d "$source" ]] || { ((skipped_count += 1)); return; }
  while IFS= read -r -d '' path; do
    relative="${path#"$source"/}"
    extension="${path##*.}"
    case ",$extensions," in
      *",$extension,"*) capture_file "$path" "$destination/$relative" ;;
    esac
  done < <(find "$source" -type f -print0 | sort -z)
}

log "Reading the portable configuration allowlist"
while IFS=$'\t' read -r scope kind source destination extensions; do
  [[ -n "$scope" && "${scope:0:1}" != "#" ]] || continue
  case "$scope" in
    home) source_path="$CAPTURE_HOME/$source" ;;
    system) source_path="$CAPTURE_ROOT/$source" ;;
    *) die "unknown allowlist scope: $scope" ;;
  esac
  case "$kind" in
    file) capture_file "$source_path" "$destination" ;;
    tree) capture_tree "$source_path" "$destination" "$extensions" ;;
    *) die "unknown allowlist kind: $kind" ;;
  esac
done < "$ALLOWLIST"

if [[ -n "${KALEIDASH_CAPTURE_OUTPUTS_JSON:-}" ]]; then
  install -m 0644 -- "$KALEIDASH_CAPTURE_OUTPUTS_JSON" "$OUTPUTS_JSON"
elif command -v niri >/dev/null 2>&1 && niri msg --json outputs > "$OUTPUTS_JSON" 2>/dev/null; then
  :
else
  printf '{}\n' > "$OUTPUTS_JSON"
  warn "Niri output names were unavailable; no output-name tokens were generated"
fi

log "Tokenizing machine-specific names and paths"
python3 - "$SNAPSHOT" "$OUTPUTS_JSON" \
  "$CAPTURE_HOME" "$CONFIG_HOME" "$DATA_HOME" "$STATE_HOME" \
  "$CAPTURE_USER" "$CAPTURE_HOSTNAME" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
outputs_path = Path(sys.argv[2])
home, config_home, data_home, state_home, username, hostname = sys.argv[3:]

try:
    payload = json.loads(outputs_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    payload = {}

records = list(payload.values()) if isinstance(payload, dict) else payload if isinstance(payload, list) else []
outputs = []
for record in records:
    if not isinstance(record, dict) or not isinstance(record.get("name"), str):
        continue
    logical = record.get("logical") if isinstance(record.get("logical"), dict) else {}
    outputs.append((logical.get("x", 0), logical.get("y", 0), record["name"]))
outputs.sort()

literal_replacements = [
    (config_home, "@XDG_CONFIG_HOME@"),
    (data_home, "@XDG_DATA_HOME@"),
    (state_home, "@XDG_STATE_HOME@"),
    (home, "@HOME@"),
]
literal_replacements.extend((name, f"@OUTPUT_{index}@") for index, (_, _, name) in enumerate(outputs, 1))
literal_replacements = sorted(
    ((source, target) for source, target in literal_replacements if source),
    key=lambda pair: len(pair[0]),
    reverse=True,
)

def strip_tables(text: str, roots: set[str]) -> str:
    result = []
    skipping = False
    for line in text.splitlines(keepends=True):
        match = re.match(r"^\s*\[\[?\s*([^\].]+)", line)
        if match:
            table_root = match.group(1).strip().strip('"').split(".", 1)[0]
            skipping = table_root in roots
        if not skipping:
            result.append(line)
    return "".join(result)

for path in sorted(root.rglob("*")):
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8")
    relative = path.relative_to(root).as_posix()
    if relative == "system/var/lib/noctalia-greeter/greeter.toml":
        text = strip_tables(text, {"output", "user"})
        text += "\n# Machine-specific display and account tables are intentionally omitted.\n"
    if relative.startswith("home/.config/noctalia/") or relative == "home/.local/state/noctalia/settings.toml":
        text = strip_tables(text, {"location"})
    for source, target in literal_replacements:
        text = text.replace(source, target)
    for source, target in ((username, "@USER@"), (hostname, "@HOSTNAME@")):
        if source and len(source) >= 3:
            text = re.sub(rf"(?<![\w-]){re.escape(source)}(?![\w-])", target, text)
    path.write_text(text, encoding="utf-8")
PY

install -m 0644 -- "$SCRIPT_DIR/CAPTURED.template.md" "$SNAPSHOT/CAPTURED.md"

"$SCRIPT_DIR/validate-snapshot" --no-manifest "$SNAPSHOT"

log "Generating deterministic manifest"
{
  printf 'mode\tsha256\tpath\n'
  while IFS= read -r -d '' path; do
    relative="${path#"$SNAPSHOT"/}"
    [[ "$relative" == "manifest.tsv" ]] && continue
    printf '%s\t%s\t%s\n' \
      "$(stat -c '%a' -- "$path")" \
      "$(sha256sum -- "$path" | cut -d ' ' -f 1)" \
      "$relative"
  done < <(find "$SNAPSHOT" -type f -print0 | sort -z)
} > "$SNAPSHOT/manifest.tsv"

"$SCRIPT_DIR/validate-snapshot" "$SNAPSHOT"

parent_dir="$(dirname -- "$output_dir")"
mkdir -p -- "$parent_dir"
replacement_dir="$(mktemp -d "$parent_dir/.kaleidash-snapshot.new.XXXXXX")"
cp -a -- "$SNAPSHOT/." "$replacement_dir/"

if [[ -e "$output_dir" ]]; then
  [[ -f "$output_dir/CAPTURED.md" ]] || die "refusing to replace an unmanaged directory: $output_dir"
  previous_dir="$(mktemp -d "$parent_dir/.kaleidash-snapshot.previous.XXXXXX")"
  rmdir -- "$previous_dir"
  mv -- "$output_dir" "$previous_dir"
  if ! mv -- "$replacement_dir" "$output_dir"; then
    mv -- "$previous_dir" "$output_dir"
    die "could not install the new snapshot; the previous snapshot was restored"
  fi
  rm -rf -- "$previous_dir"
else
  mv -- "$replacement_dir" "$output_dir"
fi

log "Capture complete"
printf '  Captured files: %d\n' "$captured_count"
printf '  Missing or skipped allowlist entries: %d\n' "$skipped_count"
printf '  Snapshot: %s\n\n' "$output_dir"
printf 'Review with: git diff -- config/snapshot\n'
