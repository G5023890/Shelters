#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$SCRIPT_DIR/Input/Raw"
OUTPUT_DIR="$SCRIPT_DIR/Output/israel-preview"

"$SCRIPT_DIR/build_sample_dataset.sh" \
  --source israel-preview-v1 \
  --source-snapshot "$RAW_DIR" \
  --output-dir "$OUTPUT_DIR" \
  "$@"
