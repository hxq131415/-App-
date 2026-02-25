#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_PATH="${1:-$ROOT_DIR/obfuscator.config.json}"

python3 "$ROOT_DIR/obfuscator/objc_obfuscator.py" --config "$CONFIG_PATH"
