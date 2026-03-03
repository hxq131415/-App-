#!/usr/bin/env bash
set -euo pipefail

# Xcode Run Script phase helper.
# Goal: generate per-build obfuscation noise source in project tree,
# so you can archive/export IPA manually from Xcode organizer.

ROOT_DIR="${SRCROOT:-${PROJECT_DIR:-$(pwd)}}"
OUT_DIR="${ROOT_DIR}/Obfuscation/Generated"
NOISE_FILE="${OUT_DIR}/OBFBuildNoise.m"
ORDER_FILE="${OUT_DIR}/link.order"
SEED_FILE="${OUT_DIR}/.obf_seed"
SIZE_KB="${OBF_PADDING_KB:-64}"

mkdir -p "$OUT_DIR"

SEED="${OBF_BUILD_SEED:-$(date +%s)-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
echo "$SEED" > "$SEED_FILE"

python3 "${ROOT_DIR}/scripts/ipa_obfuscator/shuffle_macho_symbols.py" \
  --seed "$SEED" \
  --source-root "$ROOT_DIR" \
  --order-file "$ORDER_FILE" \
  --noise-file "$NOISE_FILE" \
  --size-kb "$SIZE_KB" \
  --skip-binary

echo "[obf-run-script] seed: $SEED"
echo "[obf-run-script] noise: $NOISE_FILE"
echo "[obf-run-script] order: $ORDER_FILE"
