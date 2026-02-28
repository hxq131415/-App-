#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${ROOT_DIR}/.obf_build"
mkdir -p "${WORK_DIR}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") -s <scheme> -c <configuration> -t <team_id> -p <export_plist> [options]

Required:
  -s  Xcode scheme
  -c  Build configuration (Release)
  -t  Apple Team ID
  -p  ExportOptions.plist path

Optional:
  -w  .xcworkspace path (auto-detect if Podfile exists)
  -x  .xcodeproj path (fallback if no workspace)
  -d  DerivedData path (default: .obf_build/DerivedData)
  -o  Output directory for ipa (default: dist)
  -r  Source root to scan (can be passed multiple times, default target root)
  -k  Binary padding size in KB (default: 64)
  -n  Build number tag (default: unix timestamp)
  -P  Target iOS project root directory (default: current repo root)
EOF
}

SCHEME=""
CONFIG=""
TEAM_ID=""
EXPORT_PLIST=""
WORKSPACE=""
PROJECT=""
DERIVED_DATA="${WORK_DIR}/DerivedData"
OUT_DIR="${ROOT_DIR}/dist"
PADDING_KB=64
BUILD_TAG="$(date +%s)"
SOURCE_ROOTS=()
TARGET_ROOT="${ROOT_DIR}"

while getopts ":s:c:t:p:w:x:d:o:r:k:n:P:h" opt; do
  case "$opt" in
    s) SCHEME="$OPTARG" ;;
    c) CONFIG="$OPTARG" ;;
    t) TEAM_ID="$OPTARG" ;;
    p) EXPORT_PLIST="$OPTARG" ;;
    w) WORKSPACE="$OPTARG" ;;
    x) PROJECT="$OPTARG" ;;
    d) DERIVED_DATA="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    r) SOURCE_ROOTS+=("$OPTARG") ;;
    k) PADDING_KB="$OPTARG" ;;
    n) BUILD_TAG="$OPTARG" ;;
    P) TARGET_ROOT="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument"; usage; exit 1 ;;
    \?) echo "Invalid option: -$OPTARG"; usage; exit 1 ;;
  esac
done

[[ -n "$SCHEME" && -n "$CONFIG" && -n "$TEAM_ID" && -n "$EXPORT_PLIST" ]] || { usage; exit 1; }
TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd)"

if [[ ${#SOURCE_ROOTS[@]} -eq 0 ]]; then
  SOURCE_ROOTS=("${TARGET_ROOT}")
fi

if [[ -z "$WORKSPACE" && -f "${TARGET_ROOT}/Podfile" ]]; then
  if command -v pod >/dev/null 2>&1; then
    echo "[obf] Running pod install..."
    (cd "$TARGET_ROOT" && pod install --silent)
  fi
  WORKSPACE="$(find "$TARGET_ROOT" -maxdepth 1 -name "*.xcworkspace" | head -n1 || true)"
fi

if [[ -z "$WORKSPACE" && -z "$PROJECT" ]]; then
  PROJECT="$(find "$TARGET_ROOT" -maxdepth 1 -name "*.xcodeproj" | head -n1 || true)"
fi

[[ -n "$WORKSPACE" || -n "$PROJECT" ]] || { echo "No workspace/project found under: $TARGET_ROOT"; exit 1; }

if [[ ! -f "$EXPORT_PLIST" ]]; then
  if [[ -f "${TARGET_ROOT}/${EXPORT_PLIST}" ]]; then
    EXPORT_PLIST="${TARGET_ROOT}/${EXPORT_PLIST}"
  fi
fi
[[ -f "$EXPORT_PLIST" ]] || { echo "ExportOptions.plist not found: $EXPORT_PLIST"; exit 1; }

mkdir -p "$OUT_DIR" "$DERIVED_DATA"
SEED="${BUILD_TAG}-$(uuidgen | tr '[:upper:]' '[:lower:]')"
ARCHIVE1="${WORK_DIR}/pass1.xcarchive"
ARCHIVE2="${WORK_DIR}/pass2.xcarchive"
ORDER_FILE="${WORK_DIR}/link.order"
NOISE_FILE="${TARGET_ROOT}/Obfuscation/Generated/OBFBuildNoise.m"
mkdir -p "$(dirname "$NOISE_FILE")"

XCBUILD_ARGS=(-scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED_DATA" DEVELOPMENT_TEAM="$TEAM_ID" ENABLE_BITCODE=NO)
if [[ -n "$WORKSPACE" ]]; then
  [[ "$WORKSPACE" = /* ]] || WORKSPACE="${TARGET_ROOT}/${WORKSPACE}"
  XCBUILD_ARGS=(-workspace "$WORKSPACE" "${XCBUILD_ARGS[@]}")
else
  [[ "$PROJECT" = /* ]] || PROJECT="${TARGET_ROOT}/${PROJECT}"
  XCBUILD_ARGS=(-project "$PROJECT" "${XCBUILD_ARGS[@]}")
fi

echo "[obf] Target root: $TARGET_ROOT"
echo "[obf] Pass1 archive for symbol inventory..."
xcodebuild "${XCBUILD_ARGS[@]}" -archivePath "$ARCHIVE1" clean archive >/tmp/obf_pass1.log

APP_BIN="$(find "$ARCHIVE1/Products/Applications" -name "$SCHEME.app" -type d | head -n1)/$SCHEME"
[[ -f "$APP_BIN" ]] || { echo "Unable to locate app binary in archive"; exit 1; }

PY_ARGS=(--seed "$SEED" --binary "$APP_BIN" --order-file "$ORDER_FILE" --noise-file "$NOISE_FILE" --size-kb "$PADDING_KB")
for src in "${SOURCE_ROOTS[@]}"; do
  PY_ARGS+=(--source-root "$src")
done

python3 "${ROOT_DIR}/scripts/ipa_obfuscator/shuffle_macho_symbols.py" "${PY_ARGS[@]}"

echo "[obf] Pass2 archive with randomized layout..."
xcodebuild "${XCBUILD_ARGS[@]}" -archivePath "$ARCHIVE2" \
  OTHER_CFLAGS="
  -DOBF_BUILD_SEED=\"$SEED\"" \
  OTHER_LDFLAGS="-Wl,-order_file,${ORDER_FILE}" \
  clean archive >/tmp/obf_pass2.log

EXPORT_PATH="${OUT_DIR}/export-${BUILD_TAG}"
mkdir -p "$EXPORT_PATH"

echo "[obf] Exporting IPA..."
xcodebuild -exportArchive -archivePath "$ARCHIVE2" -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EXPORT_PLIST" >/tmp/obf_export.log

IPA_PATH="$(find "$EXPORT_PATH" -name "*.ipa" | head -n1 || true)"
[[ -n "$IPA_PATH" ]] || { echo "IPA export failed"; exit 1; }

FINAL_IPA="${OUT_DIR}/$(basename "${IPA_PATH%.ipa}")-${BUILD_TAG}.ipa"
cp "$IPA_PATH" "$FINAL_IPA"

echo "[ok] Seed: $SEED"
echo "[ok] Order file: $ORDER_FILE"
echo "[ok] Noise source: $NOISE_FILE"
echo "[ok] IPA: $FINAL_IPA"
