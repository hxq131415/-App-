#!/usr/bin/env bash
set -euo pipefail

log() { printf '[*] %s\n' "$*"; }
err() { printf '[x] %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "缺少命令: $1"; exit 1; }
}

usage() {
  cat <<'USAGE'
用法:
  # 模式1：从源码构建并混淆打包
  ./scripts/ipa_obfuscate.sh --scheme <Scheme> --export-options-plist <plist> [选项]

  # 模式2：指定输入 IPA 做二次处理（重打包混淆）
  ./scripts/ipa_obfuscate.sh --input-ipa <path.ipa> [选项]

模式1必填参数:
  --scheme <name>                 Xcode Scheme
  --export-options-plist <path>   xcodebuild -exportArchive 使用的 ExportOptions.plist

模式2必填参数:
  --input-ipa <path>              输入待二次处理的 IPA

通用可选参数:
  --output-dir <dir>              默认 ./build/obfuscated
  --output-ipa <path>             指定输出 IPA 完整路径

源码构建模式可选参数:
  --workspace <path>              指定 .xcworkspace（优先）
  --project <path>                指定 .xcodeproj
  --configuration <name>          默认 Release
  --derived-data <dir>            默认 ./build/obfuscated/DerivedData
  --archive-path <path>           默认 <output-dir>/AppObfuscated.xcarchive
  --skip-pod-install              检测到 Podfile 时跳过 pod install
  --clean                         构建前 clean

IPA 二次处理模式可选参数:
  --noise-files <n>               注入噪声文件数量（默认随机 8~24）
  --noise-size-kb <n>             每个噪声文件大小 KB（默认随机 4~64）
  --resign                        二次处理后重新签名（上架必须）
  --sign-identity <identity>      codesign identity（与 --resign 搭配）
  --provisioning-profile <path>   .mobileprovision（与 --resign 搭配）

其他:
  -h, --help                      查看帮助
USAGE
}

SCHEME=""
WORKSPACE=""
PROJECT=""
CONFIGURATION="Release"
OUTPUT_DIR="$(pwd)/build/obfuscated"
OUTPUT_IPA=""
DERIVED_DATA=""
ARCHIVE_PATH=""
EXPORT_OPTIONS_PLIST=""
INPUT_IPA=""
SKIP_POD_INSTALL=0
DO_CLEAN=0

NOISE_FILES=""
NOISE_SIZE_KB=""
DO_RESIGN=0
SIGN_IDENTITY=""
PROVISIONING_PROFILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-}"; shift 2 ;;
    --workspace)
      WORKSPACE="${2:-}"; shift 2 ;;
    --project)
      PROJECT="${2:-}"; shift 2 ;;
    --configuration)
      CONFIGURATION="${2:-}"; shift 2 ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"; shift 2 ;;
    --output-ipa)
      OUTPUT_IPA="${2:-}"; shift 2 ;;
    --derived-data)
      DERIVED_DATA="${2:-}"; shift 2 ;;
    --archive-path)
      ARCHIVE_PATH="${2:-}"; shift 2 ;;
    --export-options-plist)
      EXPORT_OPTIONS_PLIST="${2:-}"; shift 2 ;;
    --input-ipa)
      INPUT_IPA="${2:-}"; shift 2 ;;
    --skip-pod-install)
      SKIP_POD_INSTALL=1; shift ;;
    --clean)
      DO_CLEAN=1; shift ;;
    --noise-files)
      NOISE_FILES="${2:-}"; shift 2 ;;
    --noise-size-kb)
      NOISE_SIZE_KB="${2:-}"; shift 2 ;;
    --resign)
      DO_RESIGN=1; shift ;;
    --sign-identity)
      SIGN_IDENTITY="${2:-}"; shift 2 ;;
    --provisioning-profile)
      PROVISIONING_PROFILE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      err "未知参数: $1"
      usage
      exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
WORK_DIR="$OUTPUT_DIR/work"
mkdir -p "$WORK_DIR"

if [[ -n "$INPUT_IPA" ]]; then
  # ===== 模式2：输入 IPA 二次处理 =====
  [[ -f "$INPUT_IPA" ]] || { err "输入 IPA 不存在: $INPUT_IPA"; exit 1; }
  require_cmd unzip
  require_cmd zip
  require_cmd python3

  NOISE_FILES="${NOISE_FILES:-$(( (RANDOM % 17) + 8 ))}"
  NOISE_SIZE_KB="${NOISE_SIZE_KB:-$(( (RANDOM % 61) + 4 ))}"
  [[ "$NOISE_FILES" =~ ^[0-9]+$ ]] || { err "--noise-files 必须为整数"; exit 1; }
  [[ "$NOISE_SIZE_KB" =~ ^[0-9]+$ ]] || { err "--noise-size-kb 必须为整数"; exit 1; }

  if [[ $DO_RESIGN -eq 1 ]]; then
    require_cmd codesign
    [[ -n "$SIGN_IDENTITY" ]] || { err "--resign 时必须提供 --sign-identity"; exit 1; }
    [[ -n "$PROVISIONING_PROFILE" ]] || { err "--resign 时必须提供 --provisioning-profile"; exit 1; }
    [[ -f "$PROVISIONING_PROFILE" ]] || { err "provisioning profile 不存在: $PROVISIONING_PROFILE"; exit 1; }
  fi

  STAGE="$WORK_DIR/ipa_stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"

  log "[1/5] 解包输入 IPA..."
  unzip -q "$INPUT_IPA" -d "$STAGE"

  APP_DIR="$(find "$STAGE/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1 || true)"
  [[ -n "$APP_DIR" ]] || { err "未找到 Payload/*.app"; exit 1; }

  INFO_PLIST="$APP_DIR/Info.plist"
  [[ -f "$INFO_PLIST" ]] || { err "未找到 Info.plist: $INFO_PLIST"; exit 1; }

  APP_BINARY="$(python3 - "$INFO_PLIST" "$APP_DIR" <<'PY'
import plistlib, sys
from pathlib import Path
plist = Path(sys.argv[1])
app_dir = Path(sys.argv[2])
with plist.open('rb') as f:
    data = plistlib.load(f)
exe = data.get('CFBundleExecutable')
if not exe:
    print('')
else:
    p = app_dir / exe
    print(str(p) if p.exists() else '')
PY
)"

  log "[2/5] 注入二次处理噪声文件..."
  NOISE_DIR="$APP_DIR/.obfnoise"
  mkdir -p "$NOISE_DIR"
  python3 - "$NOISE_DIR" "$NOISE_FILES" "$NOISE_SIZE_KB" <<'PY'
import os, random, sys
from pathlib import Path

noise_dir = Path(sys.argv[1])
count = int(sys.argv[2])
size_kb = int(sys.argv[3])
rand = random.SystemRandom()
for i in range(count):
    name = f"n_{rand.randrange(1<<32):08x}_{i}.bin"
    p = noise_dir / name
    p.write_bytes(os.urandom(size_kb * 1024))
print(f"noise files generated: {count}, each {size_kb}KB")
PY

  log "[3/5] 修改 Info.plist 注入 obfuscation nonce..."
  python3 - "$INFO_PLIST" <<'PY'
import plistlib, time, secrets, sys
from pathlib import Path

p = Path(sys.argv[1])
with p.open('rb') as f:
    data = plistlib.load(f)
data['ObfuscationNonce'] = f"{int(time.time())}-{secrets.token_hex(8)}"
with p.open('wb') as f:
    plistlib.dump(data, f)
print('ObfuscationNonce updated')
PY

  if [[ $DO_RESIGN -eq 1 ]]; then
    log "[4/5] 重新签名（Frameworks/Plugins/App）..."
    cp -f "$PROVISIONING_PROFILE" "$APP_DIR/embedded.mobileprovision"

    while IFS= read -r item; do
      codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$item"
    done < <(find "$APP_DIR/Frameworks" "$APP_DIR/PlugIns" -type d \( -name '*.framework' -o -name '*.appex' \) 2>/dev/null | sort || true)

    if [[ -n "$APP_BINARY" && -f "$APP_BINARY" ]]; then
      codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_BINARY"
    fi
    codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_DIR"

    codesign --verify --deep --strict "$APP_DIR"
  else
    log "[4/5] 未启用重新签名（--resign）。注意：未重签名的 IPA 无法用于上架安装。"
  fi

  OUTPUT_IPA="${OUTPUT_IPA:-$OUTPUT_DIR/$(basename "${INPUT_IPA%.ipa}")_obfuscated.ipa}"
  mkdir -p "$(dirname "$OUTPUT_IPA")"

  log "[5/5] 回包输出 IPA..."
  (
    cd "$STAGE"
    rm -f "$OUTPUT_IPA"
    zip -qry "$OUTPUT_IPA" Payload
  )

  log "完成: $OUTPUT_IPA"
  exit 0
fi

# ===== 模式1：源码构建混淆 =====
[[ -n "$SCHEME" ]] || { err "未指定 --input-ipa 时，--scheme 必填"; usage; exit 1; }
[[ -n "$EXPORT_OPTIONS_PLIST" ]] || { err "未指定 --input-ipa 时，--export-options-plist 必填"; usage; exit 1; }
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || { err "ExportOptions.plist 不存在: $EXPORT_OPTIONS_PLIST"; exit 1; }

require_cmd xcodebuild
require_cmd nm
require_cmd python3

DERIVED_DATA="${DERIVED_DATA:-$OUTPUT_DIR/DerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$OUTPUT_DIR/AppObfuscated.xcarchive}"
EXPORT_DIR="$OUTPUT_DIR/export"
SYMBOL_LIST="$WORK_DIR/symbols.txt"
ORDER_FILE="$WORK_DIR/order_file.txt"
PAD_FILE="$WORK_DIR/obfpad.bin"

if [[ -f "Podfile" ]]; then
  if [[ $SKIP_POD_INSTALL -eq 0 ]]; then
    require_cmd pod
    log "检测到 Podfile，执行 pod install..."
    pod install
  else
    log "检测到 Podfile，但已按参数跳过 pod install"
  fi

  if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE="$(find . -maxdepth 1 -name '*.xcworkspace' | head -n 1)"
  fi
fi

if [[ -z "$WORKSPACE" && -z "$PROJECT" ]]; then
  PROJECT="$(find . -maxdepth 1 -name '*.xcodeproj' | head -n 1)"
fi

if [[ -z "$WORKSPACE" && -z "$PROJECT" ]]; then
  err "未找到 .xcworkspace 或 .xcodeproj，请通过参数指定"
  exit 1
fi

XCODE_TARGET_ARGS=()
if [[ -n "$WORKSPACE" ]]; then
  [[ -d "$WORKSPACE" ]] || { err "workspace 不存在: $WORKSPACE"; exit 1; }
  XCODE_TARGET_ARGS+=( -workspace "$WORKSPACE" )
  log "使用 workspace: $WORKSPACE"
else
  [[ -d "$PROJECT" ]] || { err "project 不存在: $PROJECT"; exit 1; }
  XCODE_TARGET_ARGS+=( -project "$PROJECT" )
  log "使用 project: $PROJECT"
fi

BASE_BUILD_CMD=(
  xcodebuild
  "${XCODE_TARGET_ARGS[@]}"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -sdk iphoneos
  -derivedDataPath "$DERIVED_DATA"
)

if [[ $DO_CLEAN -eq 1 ]]; then
  log "执行 clean..."
  "${BASE_BUILD_CMD[@]}" clean
fi

log "[1/4] 预构建产物，用于提取符号..."
"${BASE_BUILD_CMD[@]}" build CODE_SIGNING_ALLOWED=NO >/dev/null

APP_DIR="$(find "$DERIVED_DATA/Build/Products" -type d -name '*.app' | grep "${CONFIGURATION}-iphoneos" | head -n 1 || true)"
[[ -n "$APP_DIR" ]] || { err "未找到 .app 产物，无法提取符号"; exit 1; }

APP_BINARY="$(find "$APP_DIR" -maxdepth 1 -type f -perm -111 | head -n 1 || true)"
[[ -n "$APP_BINARY" ]] || { err "未找到可执行文件: $APP_DIR"; exit 1; }

log "提取符号: $APP_BINARY"
nm -nm "$APP_BINARY" > "$SYMBOL_LIST"

log "[2/4] 生成随机 order file（ObjC/Swift/Selector/Metadata/函数地址）..."
python3 - "$SYMBOL_LIST" "$ORDER_FILE" <<'PY'
import random
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])

objc_class = []
swift_syms = []
selector_refs = []
meta_method = []
objc_runtime_refs = []
funcs = []
all_symbols = []

line_re = re.compile(r"^[0-9a-fA-F]+\s+([A-Za-z])\s+(.+)$")

for line in src.read_text(errors="ignore").splitlines():
    m = line_re.match(line.strip())
    if not m:
        continue
    typ, sym = m.groups()
    all_symbols.append(sym)

    if sym.startswith("_OBJC_CLASS_$_"):
        objc_class.append(sym)
    if sym.startswith("$s") or sym.startswith("_$s"):
        swift_syms.append(sym)
    if "OBJC_SELECTOR_REFERENCES" in sym or "selref" in sym.lower() or "__objc_selrefs" in sym:
        selector_refs.append(sym)
    if "__OBJC_$_" in sym and "METHOD" in sym:
        meta_method.append(sym)
    if "CLASSLIST_REFERENCES" in sym or "SELREFS" in sym or "__objc_classlist" in sym:
        objc_runtime_refs.append(sym)
    if typ in ("T", "t") and sym.startswith("_"):
        funcs.append(sym)


def uniq(items):
    seen = set()
    out = []
    for i in items:
        if i in seen:
            continue
        seen.add(i)
        out.append(i)
    return out

objc_class = uniq(objc_class)
swift_syms = uniq(swift_syms)
selector_refs = uniq(selector_refs)
meta_method = uniq(meta_method)
objc_runtime_refs = uniq(objc_runtime_refs)
funcs = uniq(funcs)
all_symbols = uniq(all_symbols)

rnd = random.SystemRandom()
for bucket in (objc_class, swift_syms, selector_refs, meta_method, objc_runtime_refs, funcs):
    rnd.shuffle(bucket)

noise_pool = all_symbols[:]
rnd.shuffle(noise_pool)
noise_count = min(max(len(all_symbols) // 40, 64), 512) if all_symbols else 0
noise = noise_pool[:noise_count]

order = []
order.extend(objc_class)
order.extend(swift_syms)
order.extend(selector_refs)
order.extend(meta_method)
order.extend(objc_runtime_refs)
order.extend(noise)
order.extend(funcs)

order = uniq(order)
out.write_text("\n".join(order) + "\n")
print(f"generated order file: {out} ({len(order)} symbols)")
PY

log "[3/4] 生成随机 __DATA,__obfpad padding（影响 Mach-O 体积）..."
python3 - "$PAD_FILE" <<'PY'
import os
import random
import sys
from pathlib import Path

pad = Path(sys.argv[1])
size = random.SystemRandom().randint(1024, 64 * 1024)
pad.write_bytes(os.urandom(size))
print(f"padding size: {size} bytes")
PY

EXTRA_LDFLAGS="-Wl,-order_file,${ORDER_FILE} -Wl,-sectcreate,__DATA,__obfpad,${PAD_FILE}"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

log "[4/4] Archive + Export IPA..."
"${BASE_BUILD_CMD[@]}" archive \
  -archivePath "$ARCHIVE_PATH" \
  OTHER_LDFLAGS="\$(inherited) ${EXTRA_LDFLAGS}" >/dev/null

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_DIR" >/dev/null

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -n 1 || true)"
if [[ -n "$IPA_PATH" ]]; then
  log "完成: $IPA_PATH"
  log "order_file: $ORDER_FILE"
  log "padding: $PAD_FILE"
else
  err "导出完成但未找到 .ipa，请检查 ExportOptions.plist"
  exit 1
fi
