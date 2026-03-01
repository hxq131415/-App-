#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${ROOT_DIR}/.obf_build"
mkdir -p "${WORK_DIR}"

PASS1_LOG="${WORK_DIR}/obf_pass1.log"
PASS2_LOG="${WORK_DIR}/obf_pass2.log"
EXPORT_LOG="${WORK_DIR}/obf_export.log"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") -s <scheme> -c <configuration> -t <team_id> -p <export_plist> [options]

Required:
  -s  Xcode scheme
  -c  Build configuration (Release)
  -t  Apple Team ID (10位，如 ABCDE12345)
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
  -m  Force provisioning profile name for all archive bundle IDs (optional)
  -A  Enable xcodebuild -allowProvisioningUpdates (optional)
EOF
}

normalize_export_plist() {
  local input_path="$1"
  local output_path="$2"

  python3 - "$input_path" "$output_path" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
raw = src.read_bytes()

def normalize_obj(obj):
    if isinstance(obj, dict):
        if obj.get("method") == "development":
            obj["method"] = "debugging"
        elif obj.get("method") == "app-store":
            obj["method"] = "app-store-connect"
    return obj

for parser in (
    lambda b: plistlib.loads(b),
    lambda b: json.loads(b.decode("utf-8")),
):
    try:
        obj = normalize_obj(parser(raw))
        with dst.open("wb") as f:
            plistlib.dump(obj, f, fmt=plistlib.FMT_XML, sort_keys=True)
        raise SystemExit(0)
    except Exception:
        pass

raise SystemExit(2)
PY
}

apply_profile_mapping() {
  local base_plist="$1"
  local archive_path="$2"
  local team_id="$3"
  local profile_name="$4"
  local out_plist="$5"

  python3 - "$base_plist" "$archive_path" "$team_id" "$profile_name" "$out_plist" <<'PY'
import plistlib
import sys
from pathlib import Path

base = Path(sys.argv[1])
archive = Path(sys.argv[2])
team_id = sys.argv[3]
profile_name = sys.argv[4]
out = Path(sys.argv[5])

obj = plistlib.loads(base.read_bytes())
obj["signingStyle"] = "manual"
obj["teamID"] = team_id

bundle_ids = set()
apps = list((archive / "Products" / "Applications").glob("*.app"))
for app in apps:
    candidates = [app / "Info.plist"] + list(app.glob("PlugIns/*.appex/Info.plist"))
    for info in candidates:
        if info.exists():
            data = plistlib.loads(info.read_bytes())
            bid = data.get("CFBundleIdentifier")
            if bid:
                bundle_ids.add(bid)

obj["provisioningProfiles"] = {bid: profile_name for bid in sorted(bundle_ids)}
with out.open("wb") as f:
    plistlib.dump(obj, f, fmt=plistlib.FMT_XML, sort_keys=True)
PY
}

print_export_hints() {
  local logfile="$1"
  local archive_path="${2:-}"
  local export_plist_path="${3:-}"

  if grep -q "requires a provisioning profile with the iCloud feature" "$logfile"; then
    cat <<'EOF'
[hint] Export failed due to provisioning profile capability mismatch:
       Your app has iCloud entitlement, but selected provisioning profile does not include iCloud.
       Even if one profile supports iCloud, export can still fail when:
       - ExportOptions.plist -> provisioningProfiles maps wrong profile name for app/appex bundle id.
       - Extension targets (Notification/Share/etc.) use a different bundle id without iCloud-capable profile.
       - teamID in ExportOptions differs from profile team.
EOF

    if [[ -n "$export_plist_path" && -f "$export_plist_path" ]]; then
      python3 - "$export_plist_path" <<'PY'
import plistlib
import sys
from pathlib import Path
p = Path(sys.argv[1])
obj = plistlib.loads(p.read_bytes())
print('[hint] Effective ExportOptions:')
for key in ('method', 'signingStyle', 'teamID'):
    if key in obj:
        print(f'       {key}: {obj[key]}')
profiles = obj.get('provisioningProfiles')
if isinstance(profiles, dict) and profiles:
    print('       provisioningProfiles mapping:')
    for k, v in profiles.items():
        print(f'         {k} -> {v}')
else:
    print('       provisioningProfiles mapping: <empty>')
PY
    fi

    if [[ -n "$archive_path" && -d "$archive_path/Products/Applications" ]]; then
      python3 - "$archive_path" <<'PY'
import plistlib
import sys
from pathlib import Path
archive = Path(sys.argv[1])
apps = list((archive / 'Products' / 'Applications').glob('*.app'))
if apps:
    print('[hint] Bundle IDs found in archive (these all need matching signing/profile rules):')
for app in apps:
    for info in [app / 'Info.plist', *app.glob('PlugIns/*.appex/Info.plist')]:
        if info.exists():
            bid = plistlib.loads(info.read_bytes()).get('CFBundleIdentifier', '<unknown>')
            print(f'       - {bid}')
PY
    fi
  fi

  if grep -q 'Command line name "development" is deprecated' "$logfile"; then
    echo "[hint] ExportOptions method \"development\" is deprecated; script now normalizes it to \"debugging\"."
  fi

  if grep -q "No profiles for '" "$logfile"; then
    cat <<'EOF'
[hint] Export couldn't find matching provisioning profile for bundle id.
       1) Clean invalid files in ~/Library/MobileDevice/Provisioning Profiles (especially *.Entitlements.plist).
       2) Re-download/install the correct profile for the bundle id and team.
       3) Use -m "Profile Name" to force provisioningProfiles mapping.
       4) Optionally add -A to enable -allowProvisioningUpdates for xcodebuild.
EOF
  fi

  if grep -q 'No provisioning profile provider found for profile ".*\.mobileprovision\.Entitlements\.plist"' "$logfile"; then
    cat <<'EOF'
[hint] Invalid file found in provisioning profiles folder (*.mobileprovision.Entitlements.plist).
       Remove stray *.Entitlements.plist files under ~/Library/MobileDevice/Provisioning Profiles and retry.
EOF
  fi
}

run_step() {
  local step="$1"
  local logfile="$2"
  shift 2
  echo "[obf] ${step}..."
  if ! "$@" >"$logfile" 2>&1; then
    echo "[error] ${step} failed. Log: $logfile"
    echo "[error] Last 80 lines from $logfile:"
    tail -n 80 "$logfile" || true
    if [[ "$step" == "Exporting IPA" ]]; then
      print_export_hints "$logfile" "$ARCHIVE2" "${EFFECTIVE_EXPORT_PLIST:-$EXPORT_PLIST}"
    fi
    exit 1
  fi
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
PROFILE_NAME=""
ALLOW_PROV_UPDATES=0

while getopts ":s:c:t:p:w:x:d:o:r:k:n:P:m:Ah" opt; do
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
    m) PROFILE_NAME="$OPTARG" ;;
    A) ALLOW_PROV_UPDATES=1 ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument"; usage; exit 1 ;;
    \?) echo "Invalid option: -$OPTARG"; usage; exit 1 ;;
  esac
done

[[ -n "$SCHEME" && -n "$CONFIG" && -n "$TEAM_ID" && -n "$EXPORT_PLIST" ]] || { usage; exit 1; }
if [[ "$TEAM_ID" == *"@"* ]]; then
  echo "Invalid -t value: $TEAM_ID"
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd)"
[[ ${#SOURCE_ROOTS[@]} -gt 0 ]] || SOURCE_ROOTS=("${TARGET_ROOT}")

if [[ -z "$WORKSPACE" && -f "${TARGET_ROOT}/Podfile" ]]; then
  command -v pod >/dev/null 2>&1 && (cd "$TARGET_ROOT" && pod install --silent)
  WORKSPACE="$(find "$TARGET_ROOT" -maxdepth 1 -name "*.xcworkspace" | head -n1 || true)"
fi
[[ -n "$WORKSPACE" || -n "$PROJECT" ]] || PROJECT="$(find "$TARGET_ROOT" -maxdepth 1 -name "*.xcodeproj" | head -n1 || true)"
[[ -n "$WORKSPACE" || -n "$PROJECT" ]] || { echo "No workspace/project found under: $TARGET_ROOT"; exit 1; }

[[ -d "$EXPORT_PLIST" ]] && EXPORT_PLIST="${EXPORT_PLIST%/}/ExportOptions.plist"
if [[ ! -f "$EXPORT_PLIST" ]]; then
  [[ -d "${TARGET_ROOT}/${EXPORT_PLIST}" ]] && EXPORT_PLIST="${TARGET_ROOT}/${EXPORT_PLIST%/}/ExportOptions.plist"
  [[ -f "${TARGET_ROOT}/${EXPORT_PLIST}" ]] && EXPORT_PLIST="${TARGET_ROOT}/${EXPORT_PLIST}"
fi
[[ -f "$EXPORT_PLIST" ]] || { echo "ExportOptions.plist not found: $EXPORT_PLIST"; exit 1; }

mkdir -p "$OUT_DIR" "$DERIVED_DATA"
NORMALIZED_EXPORT_PLIST="${WORK_DIR}/ExportOptions.normalized.plist"
normalize_export_plist "$EXPORT_PLIST" "$NORMALIZED_EXPORT_PLIST" || { echo "Invalid -exportOptionsPlist format: $EXPORT_PLIST"; exit 1; }
EXPORT_PLIST="$NORMALIZED_EXPORT_PLIST"

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

ARCHIVE_XCBUILD_ARGS=("${XCBUILD_ARGS[@]}")
if [[ "$ALLOW_PROV_UPDATES" -eq 1 ]]; then
  ARCHIVE_XCBUILD_ARGS+=(-allowProvisioningUpdates)
fi

EXPORT_XCBUILD_ARGS=()
if [[ "$ALLOW_PROV_UPDATES" -eq 1 ]]; then
  EXPORT_XCBUILD_ARGS+=(-allowProvisioningUpdates)
fi

run_step "Pass1 archive for symbol inventory" "$PASS1_LOG" xcodebuild "${ARCHIVE_XCBUILD_ARGS[@]}" -archivePath "$ARCHIVE1" clean archive
APP_BIN="$(find "$ARCHIVE1/Products/Applications" -name "$SCHEME.app" -type d | head -n1)/$SCHEME"
[[ -f "$APP_BIN" ]] || { echo "Unable to locate app binary in archive"; exit 1; }

PY_ARGS=(--seed "$SEED" --binary "$APP_BIN" --order-file "$ORDER_FILE" --noise-file "$NOISE_FILE" --size-kb "$PADDING_KB")
for src in "${SOURCE_ROOTS[@]}"; do PY_ARGS+=(--source-root "$src"); done
python3 "${ROOT_DIR}/scripts/ipa_obfuscator/shuffle_macho_symbols.py" "${PY_ARGS[@]}"
[[ -s "$ORDER_FILE" ]] || { echo "Generated empty order file: $ORDER_FILE"; exit 1; }

run_step "Pass2 archive with randomized layout" "$PASS2_LOG" xcodebuild "${ARCHIVE_XCBUILD_ARGS[@]}" -archivePath "$ARCHIVE2" OTHER_CFLAGS="\$(inherited) -DOBF_BUILD_SEED=$SEED" OTHER_LDFLAGS="\$(inherited) -Wl,-order_file,${ORDER_FILE}" clean archive

EXPORT_PATH="${OUT_DIR}/export-${BUILD_TAG}"
mkdir -p "$EXPORT_PATH"
EFFECTIVE_EXPORT_PLIST="$EXPORT_PLIST"
if [[ -n "$PROFILE_NAME" ]]; then
  EFFECTIVE_EXPORT_PLIST="${WORK_DIR}/ExportOptions.effective.plist"
  apply_profile_mapping "$EXPORT_PLIST" "$ARCHIVE2" "$TEAM_ID" "$PROFILE_NAME" "$EFFECTIVE_EXPORT_PLIST"
  echo "[obf] Applied forced provisioning profile mapping: $PROFILE_NAME"
fi

run_step "Exporting IPA" "$EXPORT_LOG" xcodebuild -exportArchive "${EXPORT_XCBUILD_ARGS[@]}" -archivePath "$ARCHIVE2" -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EFFECTIVE_EXPORT_PLIST"

IPA_PATH="$(find "$EXPORT_PATH" -name "*.ipa" | head -n1 || true)"
[[ -n "$IPA_PATH" ]] || { echo "IPA export failed"; exit 1; }
FINAL_IPA="${OUT_DIR}/$(basename "${IPA_PATH%.ipa}")-${BUILD_TAG}.ipa"
cp "$IPA_PATH" "$FINAL_IPA"

echo "[ok] IPA: $FINAL_IPA"
