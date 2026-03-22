# Shelters

Offline-first Apple app foundation for iPhone and macOS that helps users in Israel find the nearest protected place or shelter from a locally stored SQLite dataset.

Current local validation status:
- macOS build passes locally with Xcode beta
- macOS tests pass locally
- iOS build could not be validated on this machine because the installed Xcode beta is missing the iOS 26.4 platform components
- production-like Netlify deployment is live at [shelters-isr.netlify.app](https://shelters-isr.netlify.app)

## What Is Implemented

- XcodeGen-based Apple project skeleton for `iOS + macOS`
- Clear layer split across `App`, `Core`, `Database`, `Features`, `Services`, `Localization`, `Resources`, and `Tests`
- Domain models for canonical places, routing points, sync metadata, reports, and settings
- SQLite wrapper with explicit migrations and WAL-ready configuration
- Repositories for canonical places, routing points, reports, photo evidence, sync metadata, and app settings
- Service protocols with local implementations and sync-ready abstractions
- SwiftUI flows for Nearby, Place Details, Reporting, and Settings
- Product-quality Place Details screen backed by canonical dataset records:
  - localized canonical name and address presentation
  - distance when current location is already available
  - user-facing verification and routing quality summaries
  - dataset freshness and source coverage context
  - route actions and place-linked reporting entry
- Localization scaffolding for English, Russian, and Hebrew
- RTL-ready app locale handling through a persisted language override
- End-to-end dataset sync flow for a published remote SQLite snapshot:
  - remote metadata fetch from `dataset-metadata.json`
  - version comparison against the installed local dataset
  - temporary snapshot download
  - SHA-256 checksum validation
  - schema and required-table validation
  - local-only table preservation during replacement
  - atomic database swap with backup and rollback
  - persisted sync state and manual sync UI
- Environment-aware publication wiring for `local`, `development`, and `production`:
  - typed app environment resolution
  - centralized dataset publication configuration
  - centralized reporting API endpoint configuration
  - clean switching between local HTTP testing and future hosted endpoints
- Local dataset builder workflow for development and sync testing:
  - curated JSON input
  - real external municipal source ingestion paths
  - multi-source canonical dataset construction with dedupe v1
  - generated `shelters.sqlite`
  - generated `dataset-metadata.json`
  - generated `dedupe-review.json` for reviewable merge cases
  - GitHub Releases-compatible publication prep for release artifacts
  - deterministic local sample geography for Israel-oriented nearby search
- Local nearby search based on SQLite, preferred routing point selection, distance utilities, initial ranking, and DB-backed place details
- Routing integration for Apple Maps, Google Maps, and Waze with preferred-provider settings and fallback URL handling
- Reporting lifecycle with local-first pending report persistence, explicit upload states, photo evidence metadata storage, retry handling, and queue-backed status UI
- Stabilization fixes for routing precedence, sync state handling, and reporting dataset-version persistence

## Architecture Notes

- `SQLite` is the primary local store, and schema evolution starts with explicit migrations.
- `canonical_places` keeps object coordinates separate from entrance coordinates and also stores a derived preferred routing coordinate for nearby query efficiency.
- Preferred routing precedence is consistent across domain models, nearby UI, and place details fallback:
  - entrance coordinates
  - stored preferred routing coordinate
  - object coordinate fallback
- Nearby query foundation is local-only and uses bounding-box filtering plus scoring hooks for confidence, routing quality, public access, and accessibility.
- User reports are stored in their own tables and never mutate canonical place data directly.
- Sync is implemented as a published-artifact client flow, not a live shelter API flow:
  - the app fetches a remote `dataset-metadata.json`
  - the metadata points to a downloadable `shelters.sqlite` snapshot
  - the client validates checksum and schema compatibility before activation
  - the live SQLite file is replaced atomically only after validation succeeds
  - the previous database is kept as a backup and restoration target if replacement fails
  - local user-owned state is merged into the staged snapshot before activation so pending reports, settings, and sync state survive dataset updates
  - the same `SQLiteDatabase` instance is reopened after replacement, so repositories and services keep working without rebuilding the app container
- Nearby search is now local and offline-first:
  - Core Location provides the current device position
  - SQLite performs nearby candidate prefiltering
  - preferred routing targets are resolved before ranking and routing
  - ranking considers distance, confidence, routing quality, public access, accessibility, and status
  - place details load from repositories instead of static placeholder data
- Place Details is now data-driven and product-facing:
  - the screen reads canonical place rows plus `routing_points`, `source_attribution`, and sync status
  - multilingual name/address rendering follows the selected app language with fallback to English/original values
  - trust information is translated into verification and routing quality labels instead of raw scores only
  - source coverage is summarized compactly from canonical multi-source attribution
  - users can open route actions or start a place-linked report directly from the details screen
- Routing is now integrated without requiring a live shelter API:
  - route actions open from local place data only
  - preferred navigation provider is stored in app settings
  - place details uses preferred routing target resolution before building route URLs
  - Google Maps and Waze use browser-safe fallbacks when native app schemes are unavailable
- Reporting is now local-first and queue-based:
  - report drafts are saved into `user_reports` without mutating canonical place rows
  - report lifecycle is explicit: `draft -> pending_upload -> uploading -> uploaded | failed`
  - upload attempt counts, failure reasons, and last-attempt timestamps are persisted on the report itself
  - photo evidence is stored separately in `photo_evidence` with captured date, EXIF coordinates, checksum, and local file path
  - pending uploads are tracked in `pending_uploads` per report and per photo for future background sync wiring
  - retry is implemented by re-queuing failed report items and photo items without rewriting canonical data
  - reporting UI shows pending reports, upload queue items, report history, and per-report upload details
  - transport is intentionally abstracted behind `ReportUploadTransport`; the app can now talk to real HTTP reporting endpoints when configured, while still staying honest and unavailable when no backend endpoint is configured
- Nearby permission flow is intentionally explicit:
  - opening the Nearby screen does not auto-trigger a location permission prompt
  - the first permission request comes from direct user action
- Minimal backend wiring now exists for reporting uploads:
  - Netlify Functions-compatible handlers are included for reports and photo metadata uploads
  - local file-backed dev storage is included for development and end-to-end testing
  - production-like Netlify deployment now serves the current dataset artifact and reporting endpoints from one site
  - canonical place data is never mutated by this backend
  - moderation and production persistence are still intentionally deferred

## Publication Contract

Published dataset artifacts are expected to be:

- `dataset-metadata.json`
- `shelters.sqlite`

The metadata document is the contract between the publication pipeline and the app client. Required fields:

- `datasetVersion`
- `publishedAt`
- `schemaVersion`
- `checksum`
- `downloadURL`
- `recordCount`
- `buildNumber`

Optional fields:

- `minimumClientVersion`
- `fileSize`

Example GitHub Releases-compatible metadata:

```json
{
  "datasetVersion": "2026.03.13-01",
  "publishedAt": "2026-03-13T10:00:00.000Z",
  "schemaVersion": 2,
  "checksum": "7f440c90d474db47c7c1fb8f919a3b30e1a6ab7f8f8ab3381030da9f18bdf524",
  "downloadURL": "https://github.com/example/shelters/releases/download/2026.03.13-01/shelters.sqlite",
  "recordCount": 262,
  "buildNumber": 13,
  "minimumClientVersion": "1.0.0"
}
```

The client only needs the metadata URL. The snapshot download URL can point to GitHub Releases, Netlify-hosted static files, or any equivalent HTTPS artifact URL.

The repository now also includes a lightweight publication-prep script that rewrites generated metadata to GitHub Releases-compatible artifact URLs while keeping the metadata contract unchanged.

## Sync Contract

The client expects a published metadata document with this shape:

```json
{
  "datasetVersion": "2026.03.13-01",
  "publishedAt": "2026-03-13T10:00:00Z",
  "schemaVersion": 1,
  "checksum": "sha256-hex-string",
  "downloadURL": "https://example.com/releases/shelters.sqlite",
  "recordCount": 12345,
  "buildNumber": 42,
  "minimumClientVersion": "1.0.0"
}
```

The SQLite snapshot is treated as a published artifact. The app does not ingest multiple public shelter sources directly on-device.

## Reporting Flow

1. A report is created locally from `CreateReportView` or a place-linked reporting entry point.
2. The report is first persisted as `draft`, then promoted to `pending_upload` with a queue item in `pending_uploads`.
3. Photo evidence is prepared through a dedicated metadata abstraction and stored separately in `photo_evidence`.
4. Attaching a photo creates a dedicated photo upload queue item linked to the report.
5. A manual upload action asks `ReportingService` to process pending uploads:
   - report state becomes `uploading`
   - upload attempt counters and timestamps are updated
   - the report payload is sent first
   - photo payloads are sent only after the report upload succeeds
6. Successful uploads mark both the report and its queue items as `uploaded`.
7. Failed uploads mark the report and active queue items as `failed` and persist the error text for user-visible retry.
8. Retry re-queues the selected failed report and its outstanding queue items without mutating canonical shelter records.

Current reporting implementation status:

- fully implemented locally:
  - persisted report lifecycle state machine
  - persisted queue items
  - photo metadata preparation and storage
  - manual upload and retry orchestration
  - user-visible reporting history and queue status
- still abstracted:
  - production deployment and persistence hardening for reporting uploads
  - background scheduling of upload runs
  - remote moderation or review workflow

## Sync Flow

1. `DefaultSyncService` fetches remote metadata from `SHELTERS_DATASET_METADATA_URL`.
2. The remote dataset version is compared with the installed local dataset version stored in sync metadata.
3. If a newer dataset exists, the client downloads the SQLite snapshot to a temporary location.
4. The downloaded file is validated:
   - checksum must match
   - remote schema version must match the supported client schema version
   - `minimumClientVersion`, when present, must be satisfied
   - required SQLite tables must exist
   - the snapshot `schema_migrations` table must match the declared schema version
5. The downloaded snapshot is copied into a staging area.
6. Local-only tables are merged from the live database into the staged database:
   - `app_settings`
   - `sync_metadata`
   - `user_reports`
   - `photo_evidence`
   - `pending_uploads`
7. The live database is atomically replaced:
   - current DB is moved to backup
   - staged DB is moved into the live path
   - if replacement fails, the backup is restored and the installed dataset remains active
8. The live `SQLiteDatabase` instance is reopened on the replaced file.
9. Final sync status is persisted and exposed to the UI.

## Environment Configuration

The app now resolves a typed runtime environment:

- `local`
- `development`
- `production`

Use these environment variables to configure publication sources:

```bash
SHELTERS_APP_ENVIRONMENT=local|development|production
SHELTERS_DATASET_METADATA_URL=https://example.com/dataset-metadata.json
SHELTERS_NETLIFY_FUNCTIONS_BASE_URL=https://example.netlify.app/.netlify/functions
SHELTERS_REPORTS_URL=https://api.example.com/reports
SHELTERS_REPORT_PHOTOS_URL=https://api.example.com/reports/photo
```

Resolution rules:

- dataset publication:
  - if `SHELTERS_DATASET_METADATA_URL` is set, the client uses it directly
  - if it is not set and the environment is `local`, the client defaults to `http://127.0.0.1:8000/dataset-metadata.json`
  - otherwise sync stays offline-safe and reports that no metadata source is configured
- reporting upload:
  - if `SHELTERS_REPORTS_URL` and `SHELTERS_REPORT_PHOTOS_URL` are both set, the client uses those explicit endpoints
  - otherwise, if `SHELTERS_NETLIFY_FUNCTIONS_BASE_URL` is set, the client derives:
    - `/reports`
    - `/reports/photo`
  - otherwise report transport remains intentionally unavailable

This keeps URLs centralized in a typed config layer instead of spreading ad hoc endpoint strings across the app.

## Local Reporting Backend

The repository now includes a minimal Netlify Functions-compatible reporting backend under [Services/netlify-api/README.md](/Users/grigorymordokhovich/Documents/Develop/Shelters/Services/netlify-api/README.md).

Run it locally:

```bash
Services/netlify-api/run_local_backend.sh
```

That starts:

- `POST http://127.0.0.1:8888/.netlify/functions/reports`
- `POST http://127.0.0.1:8888/.netlify/functions/reports/photo`

Then launch the app with:

```bash
SHELTERS_APP_ENVIRONMENT=development
SHELTERS_NETLIFY_FUNCTIONS_BASE_URL=http://127.0.0.1:8888/.netlify/functions
```

If you want local dataset sync and local reporting backend at the same time:

```bash
SHELTERS_APP_ENVIRONMENT=development
SHELTERS_DATASET_METADATA_URL=http://127.0.0.1:8000/dataset-metadata.json
SHELTERS_NETLIFY_FUNCTIONS_BASE_URL=http://127.0.0.1:8888/.netlify/functions
```

The current backend stores accepted report metadata as JSON files in `Services/netlify-api/dev-data`. It does not store or ingest canonical shelter data and does not implement moderation.

## Production-Like Netlify Deployment

The current live validation target is:

- site: [https://shelters-isr.netlify.app](https://shelters-isr.netlify.app)
- metadata: [https://shelters-isr.netlify.app/dataset-metadata.json](https://shelters-isr.netlify.app/dataset-metadata.json)
- reports endpoint: `https://shelters-isr.netlify.app/.netlify/functions/reports`
- photos endpoint: `https://shelters-isr.netlify.app/.netlify/functions/reports/photo`

Prepare the deployable site bundle from the current canonical dataset:

```bash
Tools/DatasetBuilder/build_beer_sheva_canonical_dataset.sh
Services/netlify-api/prepare_netlify_site_bundle.sh \
  --input-dir Tools/DatasetBuilder/Output/beer-sheva-canonical \
  --site-url https://shelters-isr.netlify.app
```

Deploy it:

```bash
npx netlify deploy --prod \
  --dir Services/netlify-api/site \
  --functions Services/netlify-api/functions \
  --site fe98673f-d254-44c2-8211-18ce066fe5c9
```

Recommended app configuration for this deployed environment:

```bash
SHELTERS_APP_ENVIRONMENT=production
SHELTERS_DATASET_METADATA_URL=https://shelters-isr.netlify.app/dataset-metadata.json
SHELTERS_NETLIFY_FUNCTIONS_BASE_URL=https://shelters-isr.netlify.app/.netlify/functions
```

## Test Dataset Builder

Local development and end-to-end sync testing can use the builder under [Tools/DatasetBuilder/README.md](/Users/grigorymordokhovich/Documents/Develop/Shelters/Tools/DatasetBuilder/README.md).

Generate the curated local dataset:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh
```

Generated artifacts are written to:

- `Tools/DatasetBuilder/Output/shelters.sqlite`
- `Tools/DatasetBuilder/Output/dataset-metadata.json`

The builder uses the same app migration sources, so the generated snapshot matches the schema expected by the client.

To test sync locally:

```bash
cd Tools/DatasetBuilder/Output
python3 -m http.server 8000
```

Then launch the app with:

```bash
SHELTERS_DATASET_METADATA_URL=http://127.0.0.1:8000/dataset-metadata.json
```

For explicit local runtime selection:

```bash
SHELTERS_APP_ENVIRONMENT=local
SHELTERS_DATASET_METADATA_URL=http://127.0.0.1:8000/dataset-metadata.json
```

## GitHub Releases Publication Workflow

Prepare release-ready artifacts from the current builder output:

```bash
Tools/DatasetBuilder/publish_github_release_dataset.sh \
  --input-dir Tools/DatasetBuilder/Output/beer-sheva-canonical \
  --github-owner your-org \
  --github-repo shelters-data
```

That creates:

- `Tools/DatasetBuilder/Published/<datasetVersion>/dataset-metadata.json`
- `Tools/DatasetBuilder/Published/<datasetVersion>/shelters.sqlite`
- optional `Tools/DatasetBuilder/Published/<datasetVersion>/dedupe-review.json`

Default behavior keeps artifact names stable and rewrites `downloadURL` to:

- `https://github.com/<owner>/<repo>/releases/latest/download/shelters.sqlite`

Recommended app configuration for a production-like hosted dataset:

```bash
SHELTERS_APP_ENVIRONMENT=production
SHELTERS_DATASET_METADATA_URL=https://github.com/<owner>/<repo>/releases/latest/download/dataset-metadata.json
```

Suggested release flow:

1. Build the dataset with one of the existing builder scripts.
2. Run `publish_github_release_dataset.sh` for that output directory.
3. Create a GitHub release, preferably tagged with `datasetVersion`.
4. Upload `dataset-metadata.json` and `shelters.sqlite` with those exact filenames.
5. Point the app at the published metadata URL and trigger manual sync.

Validation checklist for a published dataset:

- metadata checksum matches the uploaded `shelters.sqlite`
- metadata `downloadURL` points to the intended GitHub release artifact URL
- the app resolves dataset publication as `githubReleases`
- `DefaultSyncService` can fetch metadata and install the snapshot
- local pending reports/settings still survive sync replacement

## External Source Pipeline

The data pipeline now supports two real external sources from the official Beer Sheva shelters package:

- package page: [data.gov.il/dataset/shelters-br7](https://data.gov.il/dataset/shelters-br7)
- source kind: `beer-sheva-shelters`
- ingestion path: official `data.gov.il` CKAN `datastore_search` API for resource `e191d913-11e4-4d87-a4b2-91587aab6611`
- source kind: `beer-sheva-shelters-itm`
- ingestion path: official `data.gov.il` CKAN `datastore_search` API for resource `6d3e5ce0-b057-4205-92c3-130b05fe69fc`

Source pipeline responsibilities now include:

- raw source connector/parser
- normalization into an internal source record
- mapping into canonical app-compatible dataset rows
- per-row source attribution persistence
- generation of app-ready `shelters.sqlite` output through the existing builder flow
- canonical multi-source dataset construction through dedupe v1

Build the pinned reproducible Beer Sheva snapshot:

```bash
Tools/DatasetBuilder/build_beer_sheva_dataset.sh
```

That produces:

- `Tools/DatasetBuilder/Output/beer-sheva-source/shelters.sqlite`
- `Tools/DatasetBuilder/Output/beer-sheva-source/dataset-metadata.json`

To fetch the live official source instead of the pinned raw snapshot:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh \
  --source beer-sheva-shelters \
  --output-dir Tools/DatasetBuilder/Output/beer-sheva-live
```

Build the canonical merged dataset from both pinned raw snapshots:

```bash
Tools/DatasetBuilder/build_beer_sheva_canonical_dataset.sh
```

That produces:

- `Tools/DatasetBuilder/Output/beer-sheva-canonical/shelters.sqlite`
- `Tools/DatasetBuilder/Output/beer-sheva-canonical/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/beer-sheva-canonical/dedupe-review.json`

Current source assumptions:

- source rows only provide shelter code plus GPS coordinates
- WGS84 source coordinates are mapped directly as object coordinates
- ITM source coordinates are converted to WGS84 before normalization
- entrance coordinates are left empty
- all records are treated as `public_shelter`
- address fields remain empty because the source does not provide them
- no multi-source conflict resolution beyond v1 explicit merge rules is implemented yet

## Netlify Reporting Contract

The client and the included minimal backend now share the same reporting contract. When the backend is not configured, the app still keeps the local queue real and surfaces transport unavailability honestly.

Expected future endpoint paths:

- `POST /.netlify/functions/reports`
- `POST /.netlify/functions/reports/photo`

Expected report upload JSON body:

```json
{
  "localReportID": "UUID",
  "canonicalPlaceID": "UUID-or-null",
  "reportType": "wrong_location",
  "datasetVersion": "2026.03.13-01",
  "textNote": "Entrance marker is offset",
  "userLat": 32.0853,
  "userLon": 34.7818,
  "suggestedEntranceLat": 32.0854,
  "suggestedEntranceLon": 34.7819,
  "localCreatedAt": "2026-03-13T09:00:00.000Z"
}
```

Expected photo upload JSON body:

```json
{
  "localPhotoID": "UUID",
  "localReportID": "UUID",
  "remoteReportID": "remote-report-id-or-null",
  "localFilePath": "/path/to/local/file.jpg",
  "checksum": "sha256-or-null",
  "exifLat": 32.0853,
  "exifLon": 34.7818,
  "capturedAt": "2026-03-13T09:01:00.000Z",
  "hasMetadata": true
}
```

## End-to-End Validation Checklist

Published dataset sync:

1. Launch the app with:
   `SHELTERS_APP_ENVIRONMENT=production`
   `SHELTERS_DATASET_METADATA_URL=https://shelters-isr.netlify.app/dataset-metadata.json`
2. Open Settings and confirm the Environment section shows the production dataset metadata URL.
3. Trigger manual sync.
4. Confirm:
   - installed dataset version updates
   - remote dataset version matches the published metadata
   - sync state ends in `Up to date`
   - last successful sync is updated
5. If sync fails, confirm the previous local database remains usable and the last error is visible.

Nearby and Place Details after sync:

1. Open Nearby after a successful sync.
2. Request location from direct user action.
3. Confirm local results populate from the synced dataset.
4. Open a place details screen and confirm:
   - localized canonical name and city
   - route actions
   - verification and routing quality labels
   - dataset version / sync freshness

Reporting upload to the live backend:

1. Launch the app with:
   `SHELTERS_NETLIFY_FUNCTIONS_BASE_URL=https://shelters-isr.netlify.app/.netlify/functions`
2. Open Reporting and confirm the backend status row shows a configured backend.
3. Create a report locally.
4. Trigger upload.
5. Confirm success or failure is visible in the reporting history and queue status.
6. Attach photo metadata and retry the upload flow.

Current validated external smoke checks:

- public `dataset-metadata.json` is reachable
- public `shelters.sqlite` is downloadable
- metadata checksum matches the downloaded snapshot
- live `POST /reports` accepts a valid payload
- live `POST /reports/photo` accepts a valid payload when paired with a prior report upload

Current implementation status:

- real now:
  - environment-aware config resolution
  - remote dataset metadata fetch against a published artifact contract
  - `URLSession` reporting transport that can talk to configured HTTP endpoints
  - compatibility with the current local reporting queue lifecycle
  - Netlify Functions-compatible local handlers for report and photo metadata uploads
  - local file-backed development storage for uploaded report metadata
- prepared only:
  - GitHub Releases publication automation
  - hosted Netlify deployment and operational hardening
  - production moderation/review backend

## Dedupe V1

Canonical source kind:

- `beer-sheva-canonical-v1`

Dedupe v1 is intentionally explicit and reviewable.

Auto-merge requires:

- same normalized city
- same `placeType`
- distance within `20m`
- matching normalized name or matching normalized address

Explicit non-merge cases:

- city mismatch
- `placeType` mismatch
- conflicting names when both are present
- conflicting addresses when both are present
- distance beyond the merge threshold

Current conflict handling:

- uncertain cases are written to `dedupe-review.json`
- they are not silently discarded
- they remain unmerged in the canonical dataset

Current canonical construction rules:

- canonical row keeps the highest-priority source as its primary geometry
- source precedence is `beer-sheva-shelters` first, then `beer-sheva-shelters-itm`
- confidence score is recalculated from source confidence plus small corroboration boosts
- preferred routing point rules remain:
  - entrance coordinates
  - strongest routing point
  - object coordinates fallback

Current Place Details TODOs:

- no full source-by-source drilldown UI yet; only a compact source coverage summary
- no embedded map preview on the details screen yet
- no UI automation around the place-linked reporting flow yet

## Validation Workflow

The repository includes automated validation for the local dataset builder and sync path in
[LocalDatasetWorkflowValidationTests.swift](/Users/grigorymordokhovich/Documents/Develop/Shelters/Tests/LocalDatasetWorkflowValidationTests.swift).

That validation covers:

- generation of both builder artifacts:
  - `shelters.sqlite`
  - `dataset-metadata.json`
- checksum verification between metadata and the generated SQLite snapshot
- schema version and required-table compatibility with the app sync contract
- local HTTP serving of the generated dataset
- end-to-end `DefaultSyncService` consumption of the local metadata and snapshot
- dataset installation into the live database
- preservation of local pending report state during replacement
- nearby-search sanity for a Tel Aviv sample cluster
- multilingual sample field availability for English, Russian, and Hebrew

Run only the builder/sync validation tests:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Shelters.xcodeproj \
  -scheme SheltersApp \
  -destination "platform=macOS" \
  -only-testing:SheltersKitTests/LocalDatasetWorkflowValidationTests \
  test
```

## Manual Sync Test Flow

1. Generate the local dataset:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh
```

2. Serve the generated files:

```bash
cd Tools/DatasetBuilder/Output
python3 -m http.server 8000
```

3. Launch the app with:

```bash
SHELTERS_DATASET_METADATA_URL=http://127.0.0.1:8000/dataset-metadata.json
```

4. Open `Settings`.
5. Trigger the manual sync action.
6. Confirm the sync status card shows:
   - the installed dataset version updated to the served sample version
   - a recent last sync attempt timestamp
   - a recent last successful sync timestamp
   - status `up_to_date`

## Manual Nearby And Localization Checks

Recommended manual sanity checks after local sync:

1. In `Settings`, switch the app language override between `English`, `Russian`, and `Hebrew`.
2. Confirm UI labels update for each language.
3. In Hebrew, confirm the current layout remains readable in RTL.
4. Use a Tel Aviv test location near `32.0853, 34.7818`.
5. Confirm top nearby results come from the Tel Aviv cluster and the ranking looks reasonable for distance plus routing quality.
6. Open place details and confirm localized name/address values render correctly for the selected app language.
7. Confirm the details screen shows verification text, entrance availability, source coverage, and route actions with sensible values.

## Project Layout

- `App/`
  Thin application entry point plus dependency bootstrap and root navigation shell.
- `Core/`
  Domain models and cross-cutting utilities.
- `Database/`
  SQLite wrapper, migrations, and repository implementations.
- `Features/`
  Minimal SwiftUI feature shells.
- `Services/`
  Service protocols and Phase 1 implementations/stubs.
- `Localization/`
  Localization keys and UI language helpers.
- `Resources/`
  Localized strings.
- `Tests/`
  Foundation tests for migrations, repository behavior, and language fallbacks.

## Build

Generate the Xcode project:

```bash
xcodegen generate
```

Build with the installed Xcode beta without changing the global developer directory:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Shelters.xcodeproj \
  -scheme SheltersApp \
  -destination "generic/platform=iOS Simulator" \
  build
```

Run tests:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Shelters.xcodeproj \
  -scheme SheltersApp \
  -destination "platform=macOS" \
  test
```

## Current Boundaries

Implemented now:

- project structure
- domain models
- SQLite schema and migrations
- repository layer
- sync metadata storage
- service boundaries and local stubs where production integrations do not exist yet
- realistic Nearby and Place Details flows
- localization scaffolding
- real dataset sync flow with stateful UI presentation
- checksum validation and temporary dataset download
- schema compatibility validation for downloaded snapshots
- atomic database replacement with backup, rollback, and safe reopen
- local nearby query and ranking from SQLite
- preferred routing target selection
- Core Location integration for on-device location requests
- route actions for Apple Maps, Google Maps, and Waze
- preferred navigation provider setting wired into place details
- local pending report creation and queue-backed reporting flow
- photo evidence draft preparation with EXIF/geotag extraction interfaces
- pending upload tracking for reports and photo evidence
- minimal Netlify Functions-compatible reporting backend wiring
- real HTTP report upload support when reporting endpoints are configured
- stabilized sync state handling so unavailable remote metadata does not leave stale remote version values in UI
- manual sync action in Settings showing:
  - installed dataset version
  - remote dataset version
  - last sync attempt
  - last successful sync
  - current sync status
- local dataset builder for deterministic sample snapshots and metadata generation
- first real external source ingestion path for Beer Sheva municipal shelters
- second real source ingestion and dedupe v1 canonical construction
- live Netlify-hosted dataset artifact serving
- live Netlify Functions reporting endpoints

Intentionally deferred:

- production-grade GitHub Releases publishing automation and CI wiring
- background upload execution for pending reports and photos
- direct camera capture UX
- moderation tooling
- conflict review tooling beyond current dedupe v1 artifacts
- dataset publication automation to GitHub Releases / Netlify

## TODO Highlights

- Publish the same dataset artifacts through GitHub Releases once the GitHub repository is populated with release assets
- Expand location handling with streaming updates, fallback accuracy tiers, and user education for denied permissions
- Add stronger user-facing localization for lower-level service error messages
- Add installed-app capability checks so route buttons can adapt their presentation before open attempts
- Add upload workers that consume `pending_uploads` when connectivity becomes available
- Add photo capture flow alongside the current file-import based evidence attachment
- Expand tests for hosted backend error bodies and deployment-specific edge cases
