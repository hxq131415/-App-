#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${1:-${ROOT_DIR}/obfuscation.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  cat <<USAGE
[ERROR] 找不到配置文件: $CONFIG_FILE
请先复制 obfuscation.env.example 为 obfuscation.env 并按你的工程修改。

示例:
  cp obfuscation.env.example obfuscation.env
  ./obfuscate_and_package.sh obfuscation.env
USAGE
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${SCHEME:?请在配置中设置 SCHEME}"
: "${CONFIGURATION:=Release}"
: "${BUILD_DIR:=${ROOT_DIR}/build}"
: "${EXPORT_METHOD:=ad-hoc}"
: "${OBFUSCATION_HEADER_PATH:=${ROOT_DIR}/Obfuscation/Confusion.h}"
: "${OBFUSCATION_SEED:=$(date +%s)}"
: "${CODE_SIGN_STYLE:=Automatic}"

WORKSPACE_ARG=()
if [[ -n "${WORKSPACE_PATH:-}" ]]; then
  WORKSPACE_ARG=(-workspace "$WORKSPACE_PATH")
elif [[ -n "${PROJECT_PATH:-}" ]]; then
  WORKSPACE_ARG=(-project "$PROJECT_PATH")
else
  echo "[ERROR] WORKSPACE_PATH 或 PROJECT_PATH 必须配置一个"
  exit 1
fi

mkdir -p "$BUILD_DIR" "$(dirname "$OBFUSCATION_HEADER_PATH")"

if [[ "${RUN_POD_INSTALL:-1}" == "1" ]]; then
  if command -v pod >/dev/null 2>&1; then
    echo "[1/6] pod install"
    pod install --project-directory "$ROOT_DIR"
  else
    echo "[WARN] 未检测到 pod 命令，已跳过 pod install"
  fi
fi

echo "[2/6] 生成混淆映射头文件"
python3 "$ROOT_DIR/tools/gen_confusion_header.py" \
  --root "$ROOT_DIR" \
  --output "$OBFUSCATION_HEADER_PATH" \
  --seed "$OBFUSCATION_SEED" \
  --min-len "${IDENTIFIER_MIN_LEN:-5}" \
  --include-prefixes "${INCLUDE_PREFIXES:-}" \
  --exclude-prefixes "${EXCLUDE_PREFIXES:-NS,UI,CA,CF,OS,WK,AV,MK,CI,CG,CT}"

ARCHIVE_PATH="$BUILD_DIR/${SCHEME}.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${EXPORT_METHOD}</string>
  <key>signingStyle</key>
  <string>${CODE_SIGN_STYLE}</string>
  <key>compileBitcode</key>
  <false/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
PLIST

COMMON_OVERRIDES=(
  "GCC_PREPROCESSOR_DEFINITIONS=$(inherited) OBFUSCATION_ENABLED=1"
  "OTHER_CFLAGS=$(inherited) -fvisibility=hidden -fvisibility-inlines-hidden -include \"$OBFUSCATION_HEADER_PATH\""
  "OTHER_CPLUSPLUSFLAGS=$(inherited) -fvisibility=hidden -fvisibility-inlines-hidden -include \"$OBFUSCATION_HEADER_PATH\""
  "STRIP_INSTALLED_PRODUCT=YES"
  "COPY_PHASE_STRIP=YES"
  "DEPLOYMENT_POSTPROCESSING=YES"
  "DEAD_CODE_STRIPPING=YES"
  "LLVM_LTO=YES"
  "DEBUG_INFORMATION_FORMAT=dwarf"
  "ONLY_ACTIVE_ARCH=NO"
)

echo "[3/6] 清理旧产物"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

echo "[4/6] archive"
xcodebuild \
  "${WORKSPACE_ARG[@]}" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive \
  "${COMMON_OVERRIDES[@]}"

echo "[5/6] export ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -n 1 || true)"
if [[ -z "$IPA_PATH" ]]; then
  echo "[ERROR] 未找到导出的 ipa，请检查签名及 xcodebuild 日志"
  exit 1
fi

echo "[6/6] 完成"
echo "Obfuscation header: $OBFUSCATION_HEADER_PATH"
echo "Archive: $ARCHIVE_PATH"
echo "IPA: $IPA_PATH"
