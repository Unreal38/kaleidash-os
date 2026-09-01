#!/usr/bin/env bash
set -Eeuo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$TEST_DIR/../.." && pwd)"
readonly BOOTSTRAP="$REPO_ROOT/bootstrap.sh"
readonly FIXTURE="$TEST_DIR/fixtures/fedora-os-release"

die() {
  printf 'Bootstrap test failure: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local output="$1"
  local expected="$2"
  grep -Fq -- "$expected" <<< "$output" || die "output did not contain: $expected"
}

bash -n "$BOOTSTRAP"

profiles="$($BOOTSTRAP profiles)"
assert_contains "$profiles" "development"
assert_contains "$profiles" "gaming"
assert_contains "$profiles" "remote-access"

default_plan="$(KALEIDASH_VENDOR_OS_RELEASE="$FIXTURE" "$BOOTSTRAP" plan)"
assert_contains "$default_plan" "Fedora Linux 44 (KDE Plasma Desktop Edition)"
assert_contains "$default_plan" "Optional profiles: none"
assert_contains "$default_plan" "Identity layer: install"
assert_contains "$default_plan" "steam-arch-transition"
assert_contains "$default_plan" $'system\tio.github.hrkfdn.ncspot\tflathub\tstable'
assert_contains "$default_plan" "External applications awaiting verified recipes (4)"
assert_contains "$default_plan" "No versions are pinned"

gaming_plan="$(KALEIDASH_VENDOR_OS_RELEASE="$FIXTURE" "$BOOTSTRAP" plan \
  --profile gaming --no-identity)"
assert_contains "$gaming_plan" "Optional profiles: gaming"
assert_contains "$gaming_plan" "Identity layer: skip"
assert_contains "$gaming_plan" "mangohud"
assert_contains "$gaming_plan" "com.modrinth.ModrinthApp"

all_plan="$(KALEIDASH_VENDOR_OS_RELEASE="$FIXTURE" "$BOOTSTRAP" plan --all-profiles)"
assert_contains "$all_plan" "tailscale-stable"
assert_contains "$all_plan" "liquidctl"
assert_contains "$all_plan" "PureRef"

if KALEIDASH_VENDOR_OS_RELEASE="$FIXTURE" "$BOOTSTRAP" plan \
  --profile does-not-exist >/dev/null 2>&1; then
  die "unknown profile unexpectedly succeeded"
fi

printf 'KaleidashOS bootstrap tests passed.\n'
