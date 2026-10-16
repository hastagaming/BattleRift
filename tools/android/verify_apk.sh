#!/usr/bin/env bash
# Verify an exported APK against tools/android/toolchain.env.
#
# Usage: verify_apk.sh APK [--version-name NAME --version-code CODE] [--signed]
# Needs ANDROID_HOME and the variables from toolchain.env in the environment.
set -uo pipefail

APK="${1:?Usage: verify_apk.sh APK [--version-name NAME --version-code CODE] [--signed]}"
shift
EXPECT_NAME=""
EXPECT_CODE=""
CHECK_SIGNATURE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version-name) EXPECT_NAME="${2:?missing value}"; shift 2 ;;
    --version-code) EXPECT_CODE="${2:?missing value}"; shift 2 ;;
    --signed) CHECK_SIGNATURE=1; shift ;;
    *) echo "::error::Unknown argument $1"; exit 2 ;;
  esac
done

: "${ANDROID_HOME:?ANDROID_HOME is not set}"
: "${ANDROID_BUILD_TOOLS:?ANDROID_BUILD_TOOLS is not set}"
: "${ANDROID_MIN_SDK:?ANDROID_MIN_SDK is not set}"
: "${ANDROID_TARGET_SDK:?ANDROID_TARGET_SDK is not set}"
: "${ANDROID_COMPILE_SDK:?ANDROID_COMPILE_SDK is not set}"
: "${ANDROID_PACKAGE:?ANDROID_PACKAGE is not set}"

BT="$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS"
AAPT2="$BT/aapt2"
APKSIGNER="$BT/apksigner"
MIN_SIZE=5242880
FAILED=0

fail() {
  echo "::error::$1"
  FAILED=1
}

[ -f "$APK" ] || { echo "::error::APK not found: $APK"; exit 1; }
[ -x "$AAPT2" ] || { echo "::error::aapt2 not found in build-tools $ANDROID_BUILD_TOOLS"; exit 1; }

SIZE=$(stat -c %s "$APK")
echo "APK: $APK ($SIZE bytes)"
[ "$SIZE" -ge "$MIN_SIZE" ] || fail "The APK is only $SIZE bytes. A real export is larger than $MIN_SIZE bytes."

BADGING=$(mktemp)
MANIFEST=$(mktemp)
trap 'rm -f "$BADGING" "$MANIFEST"' EXIT
"$AAPT2" dump badging "$APK" > "$BADGING" || { echo "::error::aapt2 could not read the APK"; exit 1; }
"$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" > "$MANIFEST" || { echo "::error::aapt2 could not read the manifest"; exit 1; }
grep -E "^package:|^sdkVersion:|^targetSdkVersion:|^native-code:" "$BADGING"

grep -q "^package: name='$ANDROID_PACKAGE'" "$BADGING" || fail "Package identifier is not $ANDROID_PACKAGE"
grep -q "^sdkVersion:'$ANDROID_MIN_SDK'" "$BADGING" || fail "minSdkVersion is not $ANDROID_MIN_SDK"
grep -q "^targetSdkVersion:'$ANDROID_TARGET_SDK'" "$BADGING" || fail "targetSdkVersion is not $ANDROID_TARGET_SDK"
grep -q "compileSdkVersion='$ANDROID_COMPILE_SDK'" "$BADGING" || echo "::warning::compileSdkVersion $ANDROID_COMPILE_SDK was not found in the APK manifest"
grep -q "^native-code:.*'arm64-v8a'" "$BADGING" || fail "The APK has no arm64-v8a native code"
grep -E "enableOnBackInvokedCallback.*(=false|=\(type 0x12\)0x0)" "$MANIFEST" > /dev/null || fail "android:enableOnBackInvokedCallback=false is missing from the APK manifest"
grep -q "PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY" "$MANIFEST" || fail "PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY is missing from the APK manifest"
grep -q "android.permission.INTERNET" "$BADGING" || fail "The INTERNET permission is missing from the APK"

if [ -n "$EXPECT_CODE" ]; then
  grep -q "^package: .*versionCode='$EXPECT_CODE'" "$BADGING" || fail "versionCode in the APK is not $EXPECT_CODE"
fi
if [ -n "$EXPECT_NAME" ]; then
  grep -q "^package: .*versionName='$EXPECT_NAME'" "$BADGING" || fail "versionName in the APK is not $EXPECT_NAME"
fi

if [ "$CHECK_SIGNATURE" -eq 1 ]; then
  [ -x "$APKSIGNER" ] || { echo "::error::apksigner not found in build-tools $ANDROID_BUILD_TOOLS"; exit 1; }
  CERTS=$("$APKSIGNER" verify --verbose --print-certs "$APK" 2>&1) || { echo "$CERTS"; fail "apksigner verify failed"; CERTS=""; }
  if [ -n "$CERTS" ]; then
    echo "$CERTS" | grep -E "Verifies|Number of signers|certificate SHA-256 digest|certificate DN"
    echo "$CERTS" | grep -qE "Verified using v(2|3) scheme .*: true" || fail "The APK has no valid v2 or v3 signature"
    if echo "$CERTS" | grep -qE "CN=BattleRift CI|CN=Android Debug"; then
      fail "The APK is signed with a temporary CI or debug key, not the release key"
    fi
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  echo "APK verification failed."
  exit 1
fi
echo "APK verification passed."