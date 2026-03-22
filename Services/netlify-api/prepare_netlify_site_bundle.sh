#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INPUT_DIR="$REPO_ROOT/Tools/DatasetBuilder/Output/israel-preview"
OUTPUT_DIR="$SCRIPT_DIR/site"
SITE_URL="https://shelters-isr.netlify.app"

print_usage() {
  cat <<'EOF'
Usage:
  Services/netlify-api/prepare_netlify_site_bundle.sh [options]

Options:
  --input-dir <path>    Built dataset directory containing shelters.sqlite and dataset-metadata.json.
  --output-dir <path>   Netlify publish directory to prepare.
  --site-url <url>      Public site base URL written into dataset-metadata.json.
  --help                Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      INPUT_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --site-url)
      SITE_URL="$2"
      shift 2
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unsupported argument: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

METADATA_SOURCE="$INPUT_DIR/dataset-metadata.json"
SNAPSHOT_SOURCE="$INPUT_DIR/shelters.sqlite"
REVIEW_SOURCE="$INPUT_DIR/dedupe-review.json"

if [[ ! -f "$METADATA_SOURCE" || ! -f "$SNAPSHOT_SOURCE" ]]; then
  echo "Expected dataset artifacts were not found in $INPUT_DIR" >&2
  exit 1
fi

EXPECTED_CHECKSUM="$(python3 - "$METADATA_SOURCE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    print(json.load(handle)["checksum"])
PY
)"
ACTUAL_CHECKSUM="$(shasum -a 256 "$SNAPSHOT_SOURCE" | awk '{print $1}')"

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
  echo "Checksum mismatch between metadata and snapshot." >&2
  exit 1
fi

rm -f "$OUTPUT_DIR/dataset-metadata.json" "$OUTPUT_DIR/shelters.sqlite" "$OUTPUT_DIR/dedupe-review.json" "$OUTPUT_DIR/index.html"
cp "$SNAPSHOT_SOURCE" "$OUTPUT_DIR/shelters.sqlite"

python3 - "$METADATA_SOURCE" "$OUTPUT_DIR/dataset-metadata.json" "$SITE_URL" "$SNAPSHOT_SOURCE" <<'PY'
import json
import os
import sys

source_path, target_path, site_url, snapshot_path = sys.argv[1:]
with open(source_path, "r", encoding="utf-8") as handle:
    metadata = json.load(handle)

metadata["downloadURL"] = site_url.rstrip("/") + "/shelters.sqlite"
metadata["fileSize"] = os.path.getsize(snapshot_path)

with open(target_path, "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

if [[ -f "$REVIEW_SOURCE" ]]; then
  cp "$REVIEW_SOURCE" "$OUTPUT_DIR/dedupe-review.json"
fi

python3 - "$OUTPUT_DIR/dataset-metadata.json" "$OUTPUT_DIR/index.html" "$SITE_URL" <<'PY'
import json
import sys

metadata_path, index_path, site_url = sys.argv[1:]
with open(metadata_path, "r", encoding="utf-8") as handle:
    metadata = json.load(handle)

html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Shelters ISR Publication</title>
    <style>
      body {{ font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif; margin: 0; background: #f5f7fb; color: #18212f; }}
      main {{ max-width: 820px; margin: 0 auto; padding: 56px 24px 72px; }}
      .card {{ background: white; border-radius: 20px; padding: 24px; box-shadow: 0 18px 48px rgba(24, 33, 47, 0.08); }}
      h1 {{ margin-top: 0; font-size: 32px; }}
      dl {{ display: grid; grid-template-columns: max-content 1fr; gap: 12px 16px; }}
      dt {{ font-weight: 600; }}
      code {{ word-break: break-all; }}
      a {{ color: #0d5bd7; }}
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <h1>Shelters ISR dataset publication</h1>
        <p>This site serves the current app dataset artifact and Netlify Functions-compatible reporting endpoints.</p>
        <dl>
          <dt>Dataset version</dt><dd>{metadata["datasetVersion"]}</dd>
          <dt>Published at</dt><dd>{metadata["publishedAt"]}</dd>
          <dt>Record count</dt><dd>{metadata["recordCount"]}</dd>
          <dt>Metadata URL</dt><dd><a href="{site_url.rstrip('/')}/dataset-metadata.json">{site_url.rstrip('/')}/dataset-metadata.json</a></dd>
          <dt>Snapshot URL</dt><dd><a href="{site_url.rstrip('/')}/shelters.sqlite">{site_url.rstrip('/')}/shelters.sqlite</a></dd>
          <dt>Reports endpoint</dt><dd><code>{site_url.rstrip('/')}/.netlify/functions/reports</code></dd>
          <dt>Photos endpoint</dt><dd><code>{site_url.rstrip('/')}/.netlify/functions/reports/photo</code></dd>
        </dl>
      </div>
    </main>
  </body>
</html>
"""

with open(index_path, "w", encoding="utf-8") as handle:
    handle.write(html)
PY

echo "Prepared Netlify site bundle in $OUTPUT_DIR"
