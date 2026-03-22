#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/Output/jerusalem-official"

"$SCRIPT_DIR/build_sample_dataset.sh" \
  --source jerusalem-official-v1 \
  --output-dir "$OUTPUT_DIR" \
  "$@"
