#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly IDENTITY_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

cat > "$test_dir/vendor" <<'EOF'
NAME="Fedora Linux"
VERSION="44 (KDE Plasma Desktop Edition)"
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (KDE Plasma Desktop Edition)"
VARIANT="KDE Plasma Desktop Edition"
VARIANT_ID=kde
ID_LIKE="rhel centos"
CPE_NAME="cpe:/o:fedoraproject:fedora:44"
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=44
EOF

"$IDENTITY_DIR/system/generate-os-release" \
  "$test_dir/vendor" "$test_dir/generated" 44

# shellcheck disable=SC1091
source "$test_dir/generated"

[[ "$NAME" == "KaleidashOS" ]]
[[ "$PRETTY_NAME" == "KaleidashOS 44 (Fedora-based)" ]]
[[ "$VARIANT" == "KaleidashOS Desktop" ]]
[[ "$LOGO" == "kaleidash" ]]
[[ "$KALEIDASHOS_ID" == "kaleidash" ]]
[[ "$KALEIDASHOS_VERSION_ID" == "44" ]]

[[ "$ID" == "fedora" ]]
[[ "$VERSION_ID" == "44" ]]
[[ "$VARIANT_ID" == "kde" ]]
[[ "$ID_LIKE" == "rhel centos" ]]
[[ "$CPE_NAME" == "cpe:/o:fedoraproject:fedora:44" ]]
[[ "$REDHAT_SUPPORT_PRODUCT" == "Fedora" ]]
[[ "$REDHAT_SUPPORT_PRODUCT_VERSION" == "44" ]]

sed 's/44/45/g' "$test_dir/vendor" > "$test_dir/vendor-45"
"$IDENTITY_DIR/system/generate-os-release" \
  "$test_dir/vendor-45" "$test_dir/generated-45" 45

unset NAME PRETTY_NAME VARIANT LOGO KALEIDASHOS_VERSION_ID VERSION_ID CPE_NAME
# shellcheck disable=SC1091
source "$test_dir/generated-45"
[[ "$PRETTY_NAME" == "KaleidashOS 45 (Fedora-based)" ]]
[[ "$KALEIDASHOS_VERSION_ID" == "45" ]]
[[ "$VERSION_ID" == "45" ]]
[[ "$CPE_NAME" == "cpe:/o:fedoraproject:fedora:45" ]]

printf 'KaleidashOS os-release compatibility test passed.\n'
