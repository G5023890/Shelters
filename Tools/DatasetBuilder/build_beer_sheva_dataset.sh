#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNAPSHOT_PATH="$SCRIPT_DIR/Input/Raw/beer-sheva-shelters-datastore.json"
OUTPUT_DIR="$SCRIPT_DIR/Output/beer-sheva-source"

"$SCRIPT_DIR/build_sample_dataset.sh" \
  --source beer-sheva-shelters \
  --source-snapshot "$SNAPSHOT_PATH" \
  --output-dir "$OUTPUT_DIR" \
  "$@"
