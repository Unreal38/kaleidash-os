#!/usr/bin/env bash
set -Eeuo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BUNDLE_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
readonly FIXTURE="$TEST_DIR/fixtures/niri-outputs.json"

die() {
  printf 'Lock-screen test failure: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || die "generated config did not contain: $expected"
}

for script in install.sh uninstall.sh kaleidash-lock tests/test-lockscreen.sh; do
  bash -n "$BUNDLE_DIR/$script"
done

generated="$(mktemp)"
trap 'rm -f -- "$generated"' EXIT
"$BUNDLE_DIR/generate-config" "$FIXTURE" /tmp/kaleidash-mark.svg "$generated"

python3 - "$generated" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as stream:
    config = tomllib.load(stream)

assert config["lockscreen"]["blurred_desktop"] is False
assert config["lockscreen"]["blur_intensity"] == 0.70
assert config["lockscreen"]["tint_intensity"] == 0.30
widgets = config["lockscreen_widgets"]["widget"]
assert set(widgets) == {
    "kaleidash-logo@LANDSCAPE-1",
    "kaleidash-logo@PORTRAIT-1",
    "lockscreen-login-box@LANDSCAPE-1",
    "lockscreen-login-box@PORTRAIT-1",
}
assert widgets["kaleidash-logo@LANDSCAPE-1"]["cx"] == 1280.0
assert widgets["kaleidash-logo@LANDSCAPE-1"]["cy"] == 504.0
assert widgets["lockscreen-login-box@LANDSCAPE-1"]["cy"] == 849.6
assert widgets["kaleidash-logo@PORTRAIT-1"]["cx"] == 540.0
assert widgets["lockscreen-login-box@PORTRAIT-1"]["cy"] == 1132.8
assert widgets["lockscreen-login-box@LANDSCAPE-1"]["settings"]["background_color"] == "surface_variant"
PY

assert_contains "$generated" 'image_path = "/tmp/kaleidash-mark.svg"'
assert_contains "$generated" 'layout = "compact"'
assert_contains "$generated" 'background_radius = 22.0'

if "$BUNDLE_DIR/generate-config" "$FIXTURE" relative-logo.svg "$generated" >/dev/null 2>&1; then
  die "relative logo path unexpectedly succeeded"
fi

printf 'KaleidashOS lock-screen tests passed.\n'
