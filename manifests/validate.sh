#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly INVENTORY_DIR="$REPO_DIR/inventory"

die() {
  printf 'KaleidashOS manifest error: %s\n' "$*" >&2
  exit 1
}

check_sorted_unique() {
  local file="$1"
  local filtered
  filtered="$(mktemp)"
  grep -Ev '^[[:space:]]*(#|$)' "$file" > "$filtered" || true
  if ! diff -u "$filtered" <(sort -u "$filtered"); then
    rm -f -- "$filtered"
    die "$file is not sorted and unique"
  fi
  rm -f -- "$filtered"
}

for command_name in awk diff find grep mktemp sort; do
  command -v "$command_name" >/dev/null || die "required command is missing: $command_name"
done

[[ -f "$INVENTORY_DIR/packages/dnf-userinstalled.txt" ]] || die "package inventory is missing"
[[ -f "$INVENTORY_DIR/packages/flatpak-apps.tsv" ]] || die "Flatpak inventory is missing"
[[ -f "$INVENTORY_DIR/repositories/dnf-enabled.tsv" ]] || die "repository inventory is missing"

mapfile -t dnf_files < <(find "$SCRIPT_DIR" -name dnf.txt -type f | sort)
mapfile -t external_files < <(find "$SCRIPT_DIR" -name external.txt -type f | sort)
mapfile -t repo_files < <(find "$SCRIPT_DIR" -name repositories.txt -type f | sort)
mapfile -t flatpak_files < <(find "$SCRIPT_DIR" -name flatpak.tsv -type f | sort)
mapfile -t flatpak_remote_files < <(find "$SCRIPT_DIR" -name flatpak-remotes.tsv -type f | sort)
mapfile -t service_files < <(find "$SCRIPT_DIR" \( -name system-services.txt -o -name user-services.txt \) -type f | sort)

for file in "${dnf_files[@]}" "${external_files[@]}" "${repo_files[@]}" \
  "${flatpak_files[@]}" "${flatpak_remote_files[@]}" "${service_files[@]}"; do
  check_sorted_unique "$file"
done

dnf_entries="$(mktemp)"
trap 'rm -f -- "$dnf_entries"' EXIT
grep -hEv '^[[:space:]]*(#|$)' "${dnf_files[@]}" | sort > "$dnf_entries"

if [[ -n "$(uniq -d "$dnf_entries")" ]]; then
  uniq -d "$dnf_entries" >&2
  die "DNF packages appear in more than one manifest"
fi

while IFS= read -r package; do
  grep -Fxq "$package" "$INVENTORY_DIR/packages/dnf-userinstalled.txt" \
    || die "manifest package was not present in the capture: $package"
done < "$dnf_entries"

while IFS= read -r repository; do
  awk -F '\t' -v value="$repository" '$1 == value { found=1 } END { exit !found }' \
    "$INVENTORY_DIR/repositories/dnf-enabled.tsv" \
    || die "manifest repository was not enabled in the capture: $repository"
done < <(grep -hEv '^[[:space:]]*(#|$)' "${repo_files[@]}" | sort -u)

for file in "${flatpak_files[@]}"; do
  while IFS=$'\t' read -r scope application origin branch extra; do
    [[ -z "${extra:-}" && -n "$branch" ]] || die "$file contains an invalid Flatpak row"
    awk -F '\t' -v s="$scope" -v a="$application" -v o="$origin" -v b="$branch" \
      '$1 == s && $2 == a && $3 == o && $4 == b { found=1 } END { exit !found }' \
      "$INVENTORY_DIR/packages/flatpak-apps.tsv" \
      || die "Flatpak was not present in the capture: $application"
  done < "$file"
done

for file in "${flatpak_remote_files[@]}"; do
  while IFS=$'\t' read -r scope remote url extra; do
    [[ -z "${extra:-}" && -n "$url" ]] || die "$file contains an invalid Flatpak remote row"
    awk -F '\t' -v s="$scope" -v r="$remote" -v u="$url" \
      '$1 == s && $2 == r && $3 == u { found=1 } END { exit !found }' \
      "$INVENTORY_DIR/repositories/flatpak-remotes.tsv" \
      || die "Flatpak remote was not present in the capture: $remote"
  done < "$file"
done

for file in "${service_files[@]}"; do
  inventory_file="$INVENTORY_DIR/services/system-enabled.txt"
  [[ "$file" == */user-services.txt ]] && inventory_file="$INVENTORY_DIR/services/user-enabled.txt"
  while IFS= read -r service; do
    [[ -z "$service" || "$service" == \#* ]] && continue
    grep -Fxq "$service" "$inventory_file" || die "service was not enabled in the capture: $service"
  done < "$file"
done

printf 'KaleidashOS manifests are structurally valid.\n'
