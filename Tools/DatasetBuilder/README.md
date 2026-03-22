# Dataset Builder

Local development and pipeline tool for generating a `shelters.sqlite` snapshot and matching `dataset-metadata.json` from either:

- a curated local JSON dataset
- one or more real external municipal source pipelines

## Input Format

## Curated Input Mode

The curated builder reads a single JSON document from:

- `Tools/DatasetBuilder/Input/curated-sample-places.json`

Root fields:

- `datasetVersion`
- `publishedAt`
- `buildNumber`
- `minimumClientVersion`
- `defaultSourceName`
- `places`

Each place record contains:

- multilingual names and addresses
- `placeType`
- object coordinates
- optional entrance coordinates
- optional routing points
- accessibility/public flags
- confidence/routing scores
- lifecycle timestamps

## Run

From the repository root:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh
```

Optional flags:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh \
  --input Tools/DatasetBuilder/Input/curated-sample-places.json \
  --output-dir Tools/DatasetBuilder/Output \
  --download-base-url http://127.0.0.1:8000
```

This remains the deterministic sample dataset flow used for local sync testing and nearby UI sanity checks.

## GitHub Releases-Compatible Publication

After generating artifacts, prepare a release-ready publication directory with:

```bash
Tools/DatasetBuilder/publish_github_release_dataset.sh \
  --input-dir Tools/DatasetBuilder/Output \
  --github-owner your-org \
  --github-repo shelters-data
```

By default this prepares:

- `Tools/DatasetBuilder/Published/<datasetVersion>/shelters.sqlite`
- `Tools/DatasetBuilder/Published/<datasetVersion>/dataset-metadata.json`

The publication script:

- validates that `dataset-metadata.json` matches the generated `shelters.sqlite`
- rewrites `downloadURL` to a GitHub Releases-compatible artifact URL
- keeps the dataset contract unchanged
- leaves the original builder output untouched

Default download strategy is `latest`, so the rewritten metadata points to:

- `https://github.com/<owner>/<repo>/releases/latest/download/shelters.sqlite`

This supports a stable app metadata URL:

- `https://github.com/<owner>/<repo>/releases/latest/download/dataset-metadata.json`

If you want release-tag-specific artifact URLs instead, use:

```bash
Tools/DatasetBuilder/publish_github_release_dataset.sh \
  --input-dir Tools/DatasetBuilder/Output/beer-sheva-canonical \
  --github-owner your-org \
  --github-repo shelters-data \
  --release-tag 2026.03.13-01 \
  --download-strategy tagged
```

### Release Artifact Naming Strategy

Upload these exact filenames to each GitHub release:

- `dataset-metadata.json`
- `shelters.sqlite`

Optional review artifact:

- `dedupe-review.json`

Keeping the asset names stable makes `releases/latest/download/...` usable as a production-like metadata endpoint for the app.

## Real External Sources

The first implemented external source is:

- `beer-sheva-shelters`
- official package page: [data.gov.il/dataset/shelters-br7](https://data.gov.il/dataset/shelters-br7)
- official data path used by the pipeline: `data.gov.il` CKAN `datastore_search` for resource `e191d913-11e4-4d87-a4b2-91587aab6611`

Why this source:

- it is official municipal open data
- the source is already normalized to simple point rows
- it is available through a stable JSON API path
- it is the lowest-friction first ingestion connector before multi-source dedupe exists

The second implemented external source is:

- `beer-sheva-shelters-itm`
- same official package page: [data.gov.il/dataset/shelters-br7](https://data.gov.il/dataset/shelters-br7)
- official data path used by the pipeline: `data.gov.il` CKAN `datastore_search` for resource `6d3e5ce0-b057-4205-92c3-130b05fe69fc`

Why the second source is useful:

- it is a separate published resource in the same official package
- it uses ITM projected coordinates instead of WGS84 GPS coordinates
- it lets the pipeline exercise real normalization plus multi-source dedupe without inventing synthetic inputs

### Source Pipeline Layers

The builder now keeps three explicit layers:

- raw source record
  - example fields from Beer Sheva: `_id`, `name`, `lat`, `lon`
- normalized source record
  - source identity, shelter code, city, source coordinates, normalized timestamps
- canonical app dataset row
  - app-compatible multilingual names, place type, object coordinates, status, confidence, routing quality, source attribution

### Source-Specific Mapping Assumptions

Current Beer Sheva mapping rules:

- all rows map to `public_shelter`
- `lat/lon` are treated as object coordinates and source-of-truth GPS
- entrance coordinates are not invented when absent in the source
- address fields remain empty because the source does not provide addresses
- public accessibility is assumed `true` because the municipal dataset describes shelters
- physical accessibility is currently mapped to `false` because the source has no accessibility field
- Hebrew, English, and Russian display names are derived from the shelter code
- source attribution is preserved per row through `source_attribution`

Current Beer Sheva ITM mapping rules:

- source rows map to the same `public_shelter` type
- raw `lat/lon` fields in the ITM datastore are actually northing/easting values
- the builder converts them to WGS84 GPS coordinates before normalization
- direct GPS-like WGS84 source rows remain preferred over ITM-derived coordinates when canonical rows are merged

## Canonical Multi-Source Build

The canonical v1 source kind is:

- `beer-sheva-canonical-v1`
- `petah-tikva-official-v1`
- `tel-aviv-official-v1`
- `jerusalem-official-v1`
- `miklat-national-v1`

It loads both Beer Sheva resources, normalizes them into a shared intermediate model, runs transparent dedupe rules, and emits one app-ready canonical dataset.

### Dedupe V1 Merge Rules

Automatic merge happens only when all of these are true:

- same normalized city
- same `placeType`
- spatial distance is within `20m`
- and either normalized name matches or normalized address matches

Additional exact-duplicate handling:

- same `sourceName + sourceIdentifier` collapses to one normalized source record before cross-source matching

### Explicit Non-Merge Rules

Records do not merge when any of these are true:

- different normalized city
- different `placeType`
- both names are present and conflict
- both addresses are present and conflict
- spatial distance exceeds the v1 merge threshold

### Review / Conflict Handling

The pipeline does not silently discard uncertain cases.

- near-but-not-safe matches are written to `dedupe-review.json`
- review cases are left unmerged in the canonical dataset
- the current Beer Sheva pinned snapshots produce `0` review cases, but the artifact is still generated for future sources

### Confidence And Routing Rules

- canonical object coordinates come from the highest-priority source
- current source precedence is:
  - `beer-sheva-municipal-shelters`
  - `beer-sheva-municipal-shelters-itm`
- confidence starts from the strongest source confidence and is boosted only for corroborating multi-source matches
- routing quality is also modestly boosted when two sources agree
- preferred routing target rules stay explicit:
  - entrance coordinates if any source has them
  - strongest routing point if available
  - otherwise object coordinates from the primary source

### Build From The Pinned Raw Snapshot

A reproducible raw snapshot of the Beer Sheva source is stored at:

- `Tools/DatasetBuilder/Input/Raw/beer-sheva-shelters-datastore.json`

Build from that snapshot:

```bash
Tools/DatasetBuilder/build_beer_sheva_dataset.sh
```

Outputs are written to:

- `Tools/DatasetBuilder/Output/beer-sheva-source/shelters.sqlite`
- `Tools/DatasetBuilder/Output/beer-sheva-source/dataset-metadata.json`

The pinned ITM snapshot lives at:

- `Tools/DatasetBuilder/Input/Raw/beer-sheva-shelters-itm-datastore.json`

## Additional National Source

The latest national supplemental source is:

- `miklat-national-v1`
- site: [miklat.co.il](https://miklat.co.il/ru/shelters/)
- live data files used by the pipeline:
  - `https://miklat.co.il/data/shelters-lite.json`
  - `https://miklat.co.il/data/shelters-details.json`

How it is used:

- this source is treated as supplemental rather than authoritative
- imported records default to `unverified`
- current import keeps only records that include an explicit city in the source details
- city names are mapped from Miklat's Hebrew city index to its English city index
- official municipal datasets remain preferred for cities we already ingest directly

Build only the Miklat dataset:

```bash
Tools/DatasetBuilder/build_miklat_dataset.sh
```

Current preview behavior:

- `israel-preview-v1` keeps official Beer Sheva, Petah Tikva, Tel Aviv, and Jerusalem data as primary coverage
- Miklat fills in additional nationwide cities that are not yet covered by those official connectors
- remaining curated seed cities are only kept when they are still not covered by official or Miklat sources

Build the ITM-only source:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh \
  --source beer-sheva-shelters-itm \
  --source-snapshot Tools/DatasetBuilder/Input/Raw/beer-sheva-shelters-itm-datastore.json \
  --output-dir Tools/DatasetBuilder/Output/beer-sheva-source-itm
```

Build the canonical merged dataset from both pinned raw snapshots:

```bash
Tools/DatasetBuilder/build_beer_sheva_canonical_dataset.sh
```

That produces:

- `Tools/DatasetBuilder/Output/beer-sheva-canonical/shelters.sqlite`
- `Tools/DatasetBuilder/Output/beer-sheva-canonical/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/beer-sheva-canonical/dedupe-review.json`

## Petah Tikva Official Build

The Petah Tikva source kind is:

- `petah-tikva-official-v1`

What it does today:

- fetches the official public ArcGIS Online feature layers published by Petah Tikva municipality
- combines public protected spaces, protected spaces in public institutions, and refuges
- converts ITM / EPSG:2039 coordinates to WGS84 before canonicalization
- preserves per-layer source attribution in `source_attribution`

Build it with:

```bash
Tools/DatasetBuilder/build_petah_tikva_dataset.sh
```

Outputs are written to:

- `Tools/DatasetBuilder/Output/petah-tikva-official/shelters.sqlite`
- `Tools/DatasetBuilder/Output/petah-tikva-official/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/petah-tikva-official/dedupe-review.json`

## Tel Aviv Official Build

The Tel Aviv source kind is:

- `tel-aviv-official-v1`

What it does today:

- fetches the official Tel Aviv municipal GIS `מקלטים` layer
- reads the live ArcGIS records directly from the city service
- preserves municipal source attribution in `source_attribution`
- uses official address fields as the shelter display name when available

Build it with:

```bash
Tools/DatasetBuilder/build_tel_aviv_dataset.sh
```

Outputs are written to:

- `Tools/DatasetBuilder/Output/tel-aviv-official/shelters.sqlite`
- `Tools/DatasetBuilder/Output/tel-aviv-official/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/tel-aviv-official/dedupe-review.json`

## Jerusalem Official Build

The Jerusalem source kind is:

- `jerusalem-official-v1`

What it does today:

- fetches the official Jerusalem municipal public shelters GeoJSON dataset
- imports the published shelter coordinates and official shelter numbers
- preserves municipal source attribution in `source_attribution`
- currently uses `Public Shelter <number>` as the generated display name because the official GeoJSON does not expose richer address fields

Build it with:

```bash
Tools/DatasetBuilder/build_jerusalem_dataset.sh
```

Outputs are written to:

- `Tools/DatasetBuilder/Output/jerusalem-official/shelters.sqlite`
- `Tools/DatasetBuilder/Output/jerusalem-official/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/jerusalem-official/dedupe-review.json`

## Israel Preview Build

For local product verification across multiple cities, there is also a preview-oriented source kind:

- `israel-preview-v1`

What it does today:

- starts from the official canonical Beer Sheva dataset flow
- appends the official Petah Tikva municipal shelter dataset
- appends the official Tel Aviv municipal shelter dataset
- appends the official Jerusalem municipal shelter dataset
- appends the curated multi-city seed places from `Tools/DatasetBuilder/Input/curated-sample-places.json`
- drops the curated Beer Sheva, Petah Tikva, Tel Aviv, and Jerusalem seed rows to avoid duplicate city coverage
- keeps routing points from the remaining curated cities

Why this exists:

- the repository now has four production-grade official municipal source pipelines: Beer Sheva, Petah Tikva, Tel Aviv, and Jerusalem
- the preview blend is the fastest way to test broader map UX on macOS while the next official city connectors are being added

Build it with:

```bash
Tools/DatasetBuilder/build_israel_preview_dataset.sh
```

Outputs are written to:

- `Tools/DatasetBuilder/Output/israel-preview/shelters.sqlite`
- `Tools/DatasetBuilder/Output/israel-preview/dataset-metadata.json`
- `Tools/DatasetBuilder/Output/israel-preview/dedupe-review.json`

### Build From The Live Official API

To fetch the current official source live instead of using the pinned snapshot:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh \
  --source beer-sheva-shelters \
  --output-dir Tools/DatasetBuilder/Output/beer-sheva-live
```

To build the canonical dataset from the live official API instead of pinned raw snapshots:

```bash
Tools/DatasetBuilder/build_sample_dataset.sh \
  --source beer-sheva-canonical-v1 \
  --output-dir Tools/DatasetBuilder/Output/beer-sheva-canonical-live
```

## Outputs

Generated files are written to:

- `Tools/DatasetBuilder/Output/shelters.sqlite`
- `Tools/DatasetBuilder/Output/dataset-metadata.json`

The builder:

- applies the same app migrations used by the client
- inserts canonicalized records from either curated input or source ingestion
- computes preferred routing coordinates and tile keys
- creates a standalone SQLite snapshot artifact
- computes SHA-256 checksum
- writes matching metadata JSON for sync testing
- writes `dedupe-review.json` whenever the chosen source pipeline produces reviewable merge cases

## Publication Validation Checklist

After publication prep, verify:

- `dataset-metadata.json` and `shelters.sqlite` both exist in `Published/<release-tag>/`
- metadata `checksum` matches the snapshot file
- metadata `downloadURL` points at the intended GitHub Releases URL
- the app can use:
  - `SHELTERS_APP_ENVIRONMENT=production`
  - `SHELTERS_DATASET_METADATA_URL=https://github.com/<owner>/<repo>/releases/latest/download/dataset-metadata.json`
- `DefaultSyncService` can decode the published metadata and download the snapshot artifact

## Local Sync Testing

Serve the output directory locally:

```bash
cd Tools/DatasetBuilder/Output
python3 -m http.server 8000
```

Then run the app with:

```bash
SHELTERS_DATASET_METADATA_URL=http://127.0.0.1:8000/dataset-metadata.json
```

The app will fetch metadata from the local server and download `shelters.sqlite` as if it were a published remote artifact.
