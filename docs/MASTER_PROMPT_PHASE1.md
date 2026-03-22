# Master Prompt For Codex: Shelters Phase 1

Use the following prompt as the initial implementation brief for Codex.

```text
You are building the initial foundation of a new Apple-platform app called Shelters.

Project goal:
Build an offline-first iOS + macOS app for finding nearby protected places / shelters quickly, routing to them, and preparing the product for future dataset sync and user reporting.

Target platforms:
- iOS
- macOS

Environment assumptions:
- Latest beta versions of Apple macOS / iOS / tvOS may be used during development
- Apple Silicon MacBook (13-inch, M3, 2024)
- UI direction: Apple Liquid Glass inspired

Primary product constraints:
- offline-first is mandatory
- SQLite is the primary local store
- GPS coordinates are the source of truth, not address strings
- object point and entrance point are separate concepts
- dataset updates must be atomic and rollback-safe
- user reports must not directly mutate canonical data
- routing must use the preferred routing point
- all UI strings must be localized
- Hebrew must fully support RTL
- no hardcoded UI text in SwiftUI views

Primary stack:
- Swift
- SwiftUI
- async/await
- SQLite
- GitHub for code and dataset release artifacts
- Netlify for lightweight backend endpoints

Repository strategy for this phase:
Use a single monorepo. Create a clean folder structure that can grow into:
- apps/ios-macos-client
- services/netlify-api
- tools/dataset-builder
- docs/
- schemas/

For Phase 1, focus mainly on the client foundation plus contracts needed for later sync.

What to build in Phase 1:
1. Client app foundation
- app entry
- dependency injection
- feature/module boundaries
- base app lifecycle setup

2. Database foundation
- SQLite schema
- migration system
- persistence models
- repository layer
- local metadata storage for sync state

3. Core domain models
- place models
- routing point concepts
- sync metadata models
- report queue models
- settings models

4. Localization scaffolding
- English as source of truth
- add Russian and Hebrew localizations
- string-key based localization only
- RTL-safe setup for Hebrew

5. Initial app UI shell
- tab / navigation structure or other clean shell suitable for the app
- placeholder screens for Nearby, Map, Details, Settings if needed
- no fake overdesigned screens, but structure must be production-oriented

6. Sync-ready architecture
- define DTOs / contracts for dataset version endpoint and config endpoint
- local sync metadata storage
- sync service protocols and stub implementations
- no need to fully implement network sync in this phase unless needed for architecture validation

7. Reporting-ready architecture
- local pending report entity / queue
- report type model
- photo metadata model placeholder
- submission service protocols and stubs

Important non-goals for Phase 1:
- full moderation console
- delta patches
- complex dedupe pipeline
- user accounts
- push notifications
- advanced analytics
- full dataset publication pipeline
- polished admin tools

Architecture expectations:
- SwiftUI-first
- clear module boundaries
- testable services
- repository pattern for DB access
- explicit DTO / domain / persistence model separation where useful
- no giant god objects
- small focused services
- dependency injection friendly design
- code should be ready for future growth, not a demo spike

Suggested module breakdown:

AppCore
- app entry
- dependency container
- app lifecycle
- feature flags

Database
- SQLite schema
- migrations
- repositories
- storage access

SyncEngine
- sync metadata persistence
- version/config DTOs
- dataset update workflow contracts
- checksum/schema validation contracts
- atomic replacement strategy design

LocationEngine
- define service contracts now if implementation is deferred

NearbyEngine
- define interfaces and placeholder query/ranking contracts now if implementation is deferred

RoutingEngine
- define routing provider model and preferred provider settings now

ReportingEngine
- local report creation model
- pending upload queue
- photo metadata model
- submission contracts

LocalizationLayer
- language handling
- string keys
- locale-aware formatting
- RTL support

MapUI
- app shell and placeholder composition points for future map/list/detail UI

Settings
- preferred navigation app
- language override
- last sync info
- debug/admin options placeholder

Localization rules:
- Every user-visible string must go through localization keys
- Do not place raw visible text directly inside SwiftUI views
- English strings are the source of truth
- Provide scaffolding for:
  - en
  - ru
  - he
- Hebrew must be validated conceptually for:
  - RTL layout direction
  - text alignment behavior
  - list/detail/action row layout safety
- Place type display strings must be localized in UI, not stored in DB as translated business values

Use stable enum/raw keys such as:
- public_shelter
- migunit
- protected_parking

And UI localization keys such as:
- placeType.public_shelter
- placeType.migunit
- placeType.protected_parking

Database requirements:
Design the initial SQLite schema and migration setup around a canonical_places table with at least these fields:
- id
- place_type
- city
- name_original
- name_en
- name_ru
- name_he
- address_original
- address_en
- address_ru
- address_he
- object_lat
- object_lon
- entrance_lat
- entrance_lon
- is_public
- is_accessible
- status
- confidence_score
- routing_quality
- last_verified_at
- created_at
- updated_at

Also design supporting tables or equivalent storage for:
- sync_metadata
- pending_reports
- app_settings
- routing_points if you decide not to inline everything

Data display rule for place text:
- prefer localized value for the current UI language if present
- otherwise fall back to English if present
- otherwise fall back to original value

Sync contract requirements:
Prepare models/protocols for:
- GET /dataset/version
- GET /config

Expected dataset version response should support:
- datasetVersion
- publishedAt
- checksum
- downloadURL
- schemaVersion
- minimumClientVersion
- optionally fileSize / recordCount

Expected config response should support:
- supportedLanguages
- availableRoutingProviders
- featureFlags
- minimumAppVersion
- sync policy thresholds

You do not need to fully implement remote networking in this phase, but the architecture must clearly anticipate:
- dataset version check
- dataset download
- temp file handling
- checksum validation
- schema validation
- required table validation
- atomic DB swap
- rollback to previous DB on failure

Reporting contract requirements:
Prepare models/protocols for:
- POST /reports
- POST /reports/photo

Reports should allow local queueing with fields like:
- local report id
- dataset version
- canonical place id
- report type
- current user coords
- suggested coords
- note
- app version
- locale
- created at
- upload state

Photo metadata placeholder should support fields like:
- report id
- local file reference
- exif coords
- timestamp
- upload token or remote reference

Recommended implementation style:
- prefer Swift Package modularization if it helps, or a well-structured Xcode project if more practical
- use modern Swift concurrency
- create protocols where future implementations will vary
- keep view models thin
- separate persistence DTOs from domain models when it reduces coupling

Testing expectations:
- add at least foundational tests around migrations, repositories, and localization-safe behavior where practical
- prefer a small but meaningful test base instead of zero tests

Expected deliverables:
1. A clean initial monorepo structure
2. A buildable app target or workspace foundation
3. SQLite schema and migration mechanism
4. Core models and repositories
5. Localization scaffolding for en/ru/he
6. Sync/reporting contracts and stub services
7. Minimal documentation explaining the structure and next phases

Important working style:
- Before coding, inspect the repository and adapt to what already exists
- Do not rewrite everything if there is an existing structure
- Preserve clean boundaries and readability
- Make reasonable assumptions and document them
- If a decision has long-term architectural consequences, state the tradeoff briefly in docs

Output format:
- Implement the code and file structure directly
- Also create a short docs/phase-1-foundation.md explaining:
  - chosen structure
  - module responsibilities
  - schema overview
  - localization approach
  - next recommended step for Phase 2 sync implementation

Success criteria:
- The project compiles or is very close to compiling with clearly explained gaps
- The architecture is not a toy
- The codebase is ready for Phase 2 sync implementation without major rewrites
- Localization and offline-first constraints are enforced structurally, not only described in comments
```

## Suggested Follow-Up Prompts

After the master prompt, continue with small focused prompts like:

1. `Implement only the Database module and migration system first.`
2. `Now implement the LocalizationLayer for en/ru/he and remove any hardcoded UI strings.`
3. `Now add SyncEngine contracts, DTOs, and local sync metadata persistence.`
4. `Now add a minimal Nearby feature shell using repository-backed data access.`
5. `Now add RoutingEngine provider selection and route-opening abstractions.`

## Notes

- This prompt assumes monorepo as the fastest path for early development and better Codex coordination.
- It intentionally keeps Netlify and the dataset pipeline as contracts/stubs in Phase 1.
- It is optimized for a durable foundation rather than a throwaway prototype.
