#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${1:-8888}"
DATA_DIR="${SHELTERS_REPORTING_DEV_STORAGE_DIR:-$ROOT_DIR/services/netlify-api/dev-data}"

mkdir -p "$DATA_DIR"

echo "Running local reporting backend on http://127.0.0.1:${PORT}"
echo "Using storage: $DATA_DIR"

cd "$ROOT_DIR"
SHELTERS_REPORTING_DEV_STORAGE_DIR="$DATA_DIR" \
node services/netlify-api/dev-server.js --port "$PORT" --data-dir "$DATA_DIR"
