#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/Output/miklat-national"

"$SCRIPT_DIR/build_sample_dataset.sh" \
  --source miklat-national-v1 \
  --output-dir "$OUTPUT_DIR" \
  "$@"
