#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
BUILDER_BIN="$BUILD_DIR/dataset-builder"

mkdir -p "$BUILD_DIR"

xcrun --sdk macosx swiftc \
  -o "$BUILDER_BIN" \
  "$SCRIPT_DIR"/Sources/*.swift \
  "$REPO_ROOT/Database/Migrations/DatabaseMigration.swift" \
  "$REPO_ROOT/Database/Migrations/DatabaseSchemaMigrations.swift" \
  "$REPO_ROOT/Database/Migrations/DatabaseMigrator.swift" \
  "$REPO_ROOT/Database/SQLite/SQLiteDatabase.swift" \
  "$REPO_ROOT/Database/SQLite/SQLiteError.swift" \
  "$REPO_ROOT/Database/SQLite/SQLiteRow.swift" \
  "$REPO_ROOT/Database/SQLite/SQLiteValue.swift" \
  "$REPO_ROOT/Core/Support/DateCoding.swift" \
  "$REPO_ROOT/Services/Sync/AtomicDatabaseReplacementPlan.swift" \
  -lsqlite3

"$BUILDER_BIN" "$@"
