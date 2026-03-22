#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/Output/petah-tikva-official"

"$SCRIPT_DIR/build_sample_dataset.sh" \
  --source petah-tikva-official-v1 \
  --output-dir "$OUTPUT_DIR" \
  "$@"
