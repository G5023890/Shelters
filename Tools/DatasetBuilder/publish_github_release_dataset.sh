#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/Output"
PUBLISH_ROOT="$SCRIPT_DIR/Published"
GITHUB_OWNER=""
GITHUB_REPO=""
RELEASE_TAG=""
DOWNLOAD_STRATEGY="latest"

print_usage() {
  cat <<'EOF'
Usage:
  Tools/DatasetBuilder/publish_github_release_dataset.sh [options]

Options:
  --input-dir <path>            Directory containing shelters.sqlite and dataset-metadata.json.
  --publish-dir <path>          Root directory for prepared release artifacts.
  --github-owner <owner>        GitHub repository owner or organization.
  --github-repo <repo>          GitHub repository name.
  --release-tag <tag>           Release tag to prepare. Defaults to metadata.datasetVersion.
  --download-strategy <kind>    One of: latest, tagged. Defaults to latest.
  --help                        Show this help.

Behavior:
  - validates the generated shelters.sqlite checksum against dataset-metadata.json
  - rewrites metadata.downloadURL for GitHub Releases-compatible hosting
  - copies release-ready artifacts into Published/<release-tag>/

Examples:
  Tools/DatasetBuilder/publish_github_release_dataset.sh \
    --github-owner example \
    --github-repo shelters-data

  Tools/DatasetBuilder/publish_github_release_dataset.sh \
    --input-dir Tools/DatasetBuilder/Output/beer-sheva-canonical \
    --github-owner example \
    --github-repo shelters-data \
    --release-tag 2026.03.13-01 \
    --download-strategy tagged
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      INPUT_DIR="$2"
      shift 2
      ;;
    --publish-dir)
      PUBLISH_ROOT="$2"
      shift 2
      ;;
    --github-owner)
      GITHUB_OWNER="$2"
      shift 2
      ;;
    --github-repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    --release-tag)
      RELEASE_TAG="$2"
      shift 2
      ;;
    --download-strategy)
      DOWNLOAD_STRATEGY="$2"
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

if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
  echo "--github-owner and --github-repo are required." >&2
  exit 1
fi

if [[ "$DOWNLOAD_STRATEGY" != "latest" && "$DOWNLOAD_STRATEGY" != "tagged" ]]; then
  echo "--download-strategy must be 'latest' or 'tagged'." >&2
  exit 1
fi

INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
PUBLISH_ROOT="$(mkdir -p "$PUBLISH_ROOT" && cd "$PUBLISH_ROOT" && pwd)"

METADATA_SOURCE="$INPUT_DIR/dataset-metadata.json"
SNAPSHOT_SOURCE="$INPUT_DIR/shelters.sqlite"
REVIEW_SOURCE="$INPUT_DIR/dedupe-review.json"

if [[ ! -f "$METADATA_SOURCE" ]]; then
  echo "Missing metadata artifact: $METADATA_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$SNAPSHOT_SOURCE" ]]; then
  echo "Missing snapshot artifact: $SNAPSHOT_SOURCE" >&2
  exit 1
fi

DATASET_VERSION="$(python3 - "$METADATA_SOURCE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(data["datasetVersion"])
PY
)"

if [[ -z "$RELEASE_TAG" ]]; then
  RELEASE_TAG="$DATASET_VERSION"
fi

EXPECTED_CHECKSUM="$(python3 - "$METADATA_SOURCE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(data["checksum"])
PY
)"

ACTUAL_CHECKSUM="$(shasum -a 256 "$SNAPSHOT_SOURCE" | awk '{print $1}')"

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
  echo "Checksum mismatch between dataset-metadata.json and shelters.sqlite." >&2
  echo "Expected: $EXPECTED_CHECKSUM" >&2
  echo "Actual:   $ACTUAL_CHECKSUM" >&2
  exit 1
fi

if [[ "$DOWNLOAD_STRATEGY" == "latest" ]]; then
  SNAPSHOT_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/latest/download/shelters.sqlite"
  METADATA_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/latest/download/dataset-metadata.json"
else
  SNAPSHOT_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$RELEASE_TAG/shelters.sqlite"
  METADATA_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$RELEASE_TAG/dataset-metadata.json"
fi

TARGET_DIR="$PUBLISH_ROOT/$RELEASE_TAG"
mkdir -p "$TARGET_DIR"

cp "$SNAPSHOT_SOURCE" "$TARGET_DIR/shelters.sqlite"

python3 - "$METADATA_SOURCE" "$TARGET_DIR/dataset-metadata.json" "$SNAPSHOT_DOWNLOAD_URL" "$SNAPSHOT_SOURCE" <<'PY'
import json
import os
import sys

source_path, target_path, snapshot_download_url, snapshot_path = sys.argv[1:]
with open(source_path, "r", encoding="utf-8") as handle:
    metadata = json.load(handle)

metadata["downloadURL"] = snapshot_download_url
metadata["fileSize"] = os.path.getsize(snapshot_path)

with open(target_path, "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

if [[ -f "$REVIEW_SOURCE" ]]; then
  cp "$REVIEW_SOURCE" "$TARGET_DIR/dedupe-review.json"
fi

cat <<EOF
Prepared GitHub Releases-compatible dataset artifacts:
  Release tag: $RELEASE_TAG
  Output dir:  $TARGET_DIR
  Metadata URL to configure in the app:
    $METADATA_DOWNLOAD_URL
  Snapshot download URL written into metadata:
    $SNAPSHOT_DOWNLOAD_URL

Artifacts ready to upload to the GitHub release:
  - $TARGET_DIR/dataset-metadata.json
  - $TARGET_DIR/shelters.sqlite
EOF

if [[ -f "$TARGET_DIR/dedupe-review.json" ]]; then
  echo "  - $TARGET_DIR/dedupe-review.json"
fi
