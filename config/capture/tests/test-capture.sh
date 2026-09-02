#!/usr/bin/env bash
set -Eeuo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CAPTURE_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
readonly FIXTURES="$TEST_DIR/fixtures"

die() {
  printf 'Configuration capture test failure: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || die "$file did not contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    die "$file unexpectedly contained: $unexpected"
  fi
}

bash -n "$CAPTURE_DIR/collect.sh"
python3 -m py_compile "$CAPTURE_DIR/validate-snapshot"

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
cp -a -- "$FIXTURES/source" "$test_root/source"

fixture_home="$test_root/source/home"
fixture_system="$test_root/source/system"
snapshot="$test_root/snapshot"

while IFS= read -r -d '' path; do
  sed -i "s|@FIXTURE_HOME@|$fixture_home|g" "$path"
done < <(find "$fixture_home" -type f -print0)

run_capture() {
  KALEIDASH_CAPTURE_HOME="$fixture_home" \
  KALEIDASH_CAPTURE_ROOT="$fixture_system" \
  KALEIDASH_CAPTURE_OUTPUT="$snapshot" \
  KALEIDASH_CAPTURE_OUTPUTS_JSON="$FIXTURES/outputs.json" \
  KALEIDASH_CAPTURE_USER=testuser \
  KALEIDASH_CAPTURE_HOSTNAME=test-host \
  KALEIDASH_CAPTURE_ALLOW_ROOT=1 \
    "$CAPTURE_DIR/collect.sh"
}

run_capture
"$CAPTURE_DIR/validate-snapshot" "$snapshot"

niri_config="$snapshot/home/.config/niri/config.kdl"
noctalia_config="$snapshot/home/.config/noctalia/config.toml"
noctalia_state="$snapshot/home/.local/state/noctalia/settings.toml"
greeter_config="$snapshot/system/var/lib/noctalia-greeter/greeter.toml"

assert_contains "$niri_config" '@OUTPUT_1@'
assert_contains "$niri_config" '@OUTPUT_2@'
assert_contains "$niri_config" '@XDG_CONFIG_HOME@/niri/scripts/start-shell.sh'
assert_contains "$snapshot/home/.config/fish/config.fish" '@USER@'
assert_contains "$snapshot/home/.config/fish/config.fish" '@HOSTNAME@'
[[ -x "$snapshot/home/.config/niri/scripts/start-shell.sh" ]] \
  || die "executable mode was not preserved for the Niri helper"
assert_contains "$noctalia_config" 'monitor = "@OUTPUT_2@"'
assert_not_contains "$noctalia_config" '[location]'
assert_contains "$noctalia_state" '@HOME@/Pictures/Wallpapers'
assert_not_contains "$greeter_config" '[output]'
assert_not_contains "$greeter_config" '[user]'
assert_not_contains "$greeter_config" 'testuser'
assert_contains "$greeter_config" '[session]'

cp -- "$FIXTURES/secret.toml" "$fixture_home/.local/state/noctalia/settings.toml"
run_capture >/dev/null
assert_contains "$snapshot/home/.local/state/noctalia/settings.toml" \
  'api_key = "@SECRET_NOCTALIA_WALLHAVEN_API_KEY@"'
assert_not_contains "$snapshot/home/.local/state/noctalia/settings.toml" 'fixture-secret'
assert_contains "$fixture_home/.local/state/noctalia/settings.toml" 'fixture-secret'
assert_contains "$snapshot/secrets.required" 'SECRET_NOCTALIA_WALLHAVEN_API_KEY'
"$CAPTURE_DIR/validate-snapshot" "$snapshot" >/dev/null

before="$(sha256sum "$snapshot/manifest.tsv")"
cp -- "$FIXTURES/unsafe-email.toml" "$fixture_home/.config/starship.toml"
if run_capture >/dev/null 2>&1; then
  die "capture unexpectedly accepted an email address"
fi
after="$(sha256sum "$snapshot/manifest.tsv")"
[[ "$before" == "$after" ]] || die "failed capture replaced the previous safe snapshot"

printf 'KaleidashOS configuration capture tests passed.\n'
