#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
readonly GENERATOR="$REPO_ROOT/identity/system/generate-dynamic-logo-template"

test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

for asset in kaleidash-mark.svg kaleidash-mark-compact.svg; do
  output="$test_dir/$asset.in"
  "$GENERATOR" "$REPO_ROOT/brand/logo/$asset" "$output"

  grep -Fq '{{ colors.primary.default.hex }}' "$output"
  grep -Fq '{{ colors.secondary.default.hex }}' "$output"
  grep -Fq '{{ colors.tertiary.default.hex }}' "$output"

  if grep -oE 'fill="#[0-9a-fA-F]{6}"' "$output" \
      | grep -Ev '^fill="#(000000|ffffff)"$' >/dev/null; then
    printf '%s contains a non-neutral fixed facet color\n' "$asset" >&2
    exit 1
  fi
done

printf 'KaleidashOS dynamic logo template test passed.\n'
