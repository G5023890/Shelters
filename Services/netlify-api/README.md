# Minimal Reporting Backend

This is a minimal Netlify Functions-compatible backend for the current reporting upload contract.

What it does now:

- accepts report metadata at `POST /.netlify/functions/reports`
- accepts photo evidence metadata at `POST /.netlify/functions/reports/photo`
- validates incoming JSON payloads
- writes accepted payloads into lightweight local file storage for development
- uses Netlify Blobs automatically when the Netlify runtime exposes blob context
- otherwise falls back to ephemeral `/tmp` storage on deployed Netlify Functions
- returns explicit JSON success and error responses compatible with the current app client

What it does not do yet:

- authentication
- moderation
- canonical shelter data mutation
- binary photo upload storage
- production-grade persistence

## Local Run

```bash
Services/netlify-api/run_local_backend.sh
```

Optional custom port:

```bash
Services/netlify-api/run_local_backend.sh 8888
```

Optional custom storage directory:

```bash
SHELTERS_REPORTING_DEV_STORAGE_DIR=/tmp/shelters-reporting-dev \
Services/netlify-api/run_local_backend.sh 8888
```

Local dev storage is written under:

- `Services/netlify-api/dev-data/reports`
- `Services/netlify-api/dev-data/photos`

Each accepted request is stored as a JSON file keyed by local ID. This keeps retries deterministic and easy to inspect during development.

## Production-Like Runtime Behavior

When deployed on Netlify, the handlers first try Netlify Blobs when blob context is available. Otherwise they fall back to ephemeral `/tmp` storage, which is enough for contract validation and smoke testing but should still be treated as temporary storage only.

Photo evidence uploads also accept the previously issued `remoteReportID` as a lightweight linkage signal, so the minimal deployed backend does not depend on durable cross-invocation storage to complete the report-plus-photo flow.
