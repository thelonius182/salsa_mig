# Master API Replacement Coverage Matrix

## Purpose

This document tracks completeness of the Concertzender CPNM replacement across four separate dimensions:

1. **Published API contract** — what the current API exposes.
2. **Data coverage** — whether the required durable information exists in WordPress or another source and can be represented in Salsa.
3. **Synchronization coverage** — whether WordPress → Salsa can run safely as an ongoing production process rather than as a one-time import.
4. **Production readiness** — whether the replacement can be deployed, operated, monitored, and cut over safely.

This is the migration/API **definition-of-done checklist**. It should be updated as each domain is audited.

---

## 1. Frozen API baseline

Primary reference:

- Concertzender public API docs: `https://api.concertzender.nl/docs/api`
- Frozen project snapshot: `docs/reference/concertzender-openapi-0.0.1.json`
- OpenAPI version: `3.1.0`
- API/document version: `0.0.1`
- Base server in the specification: `https://api.concertzender.nl/api/v1`

Baseline inventory:

- **18 API paths**
- **18 API operations**
- **14 component schemas**
- **10 `*Resource` schemas**
- **1 reusable response component**

The frozen specification is the primary contract reference. Live responses from the legacy API are useful when available, but must not block replacement work.

---

## 2. Status definitions

| Status | Meaning |
|---|---|
| ✅ Covered | Required behavior/data is sufficiently covered |
| 🟡 Partial | Substantial coverage exists, but work remains |
| 🚧 In progress | Currently being investigated or implemented |
| 🟠 Audit needed | Related structures exist, but mapping is not yet established |
| 🔴 Missing | No adequate replacement coverage exists yet |
| ⚪ API-only | Does not require durable migration/storage; derive in the API layer |

---

## 3. API operation inventory

| Area | Operation | Method/path | Main response |
|---|---|---|---|
| Broadcast | `broadcasts.index` | `GET /{locale}/broadcasts/{date}` | `BroadcastResource[]` |
| Channel | `channels.index` | `GET /{locale}/channels` | `ChannelResource[]` |
| Channel | `channels.show` | `GET /{locale}/channels/{id}` | needs real-response verification |
| Episode | `episodes.index` | `GET /{locale}/episodes` | `EpisodeResource[]` |
| Episode | `episodes.show` | `GET /{locale}/episodes/{id}` | `EpisodeResource` |
| Index | `index` | `GET /{locale}` | endpoint directory |
| Page | `pages.index` | `GET /{locale}/pages` | `PageResource[]` |
| Playlist | `playlists.index` | `GET /{locale}/playlists` | `PlaylistIndexResource[]` |
| Playlist | `playlists.show` | `GET /{locale}/playlists/{id}` | `PlaylistResource` |
| Playlist | `playlists.taxonomy.index` | `GET /{locale}/playlists/{taxonomyType}/index` | `PlaylistTaxonomyResource[]` |
| Playlist | `playlists.taxonomy.playlist.index` | `GET /{locale}/playlists/taxonomy/{taxonomyId}` | `PlaylistIndexResource[]` |
| Post | `posts.index` | `GET /{locale}/posts` | `PostIndexResource[]` |
| Post | `posts.show` | `GET /{locale}/posts/{id}` | `PostResource` |
| Program | `programs.index` | `GET /{locale}/programs` | `ProgramResource[]` |
| Program | `programs.show` | `GET /{locale}/programs/{id}` | `ProgramResource` |
| Program | `programs.episodes.index` | `GET /{locale}/programs/{id}/episodes` | `EpisodeResource[]` |
| Search | `search` | `GET /{locale}/search/{query}` | `SearchCollection` |
| Search | `search.type` | `GET /{locale}/search/{entryType}/{query}` | `SearchCollection` |

---

## 4. OpenAPI schema inventory

### Resource schemas

1. `BroadcastResource`
2. `ChannelResource`
3. `EpisodeResource`
4. `PageResource`
5. `PlaylistIndexResource`
6. `PlaylistResource`
7. `PlaylistTaxonomyResource`
8. `PostIndexResource`
9. `PostResource`
10. `ProgramResource`

### Supporting schemas

11. `ApiRequestStatus`
12. `EntryType`
13. `SearchCollection`
14. `TaxonomyType`

### Reusable responses

- `ModelNotFoundException`

---

# 5. Master replacement coverage

The original wide matrix has been split into smaller tables so it remains readable in Markdown.  
The spreadsheet companion (`api_replacement_coverage.xlsx`) contains the full filterable matrix.

## 5.1 Data and API coverage

| Schema / area | Source data | Salsa storage | Extraction | Replacement API | Status |
|---|---|---|---|---|---|
| `ProgramResource` | ✅ | ✅ | ✅ | 🟡 audit in progress | 🟡 |
| `EpisodeResource` | 🟡 | ✅ | 🚧 next | 🟠 | 🚧 |
| `BroadcastResource` | 🟡 | ✅ | 🚧 next | 🟠 | 🚧 |
| `ChannelResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 |
| `PostResource` | 🟡 | ✅ | 🟡 | 🟠 | 🟡 |
| `PostIndexResource` | 🟡 | ✅ | 🟡 | 🟠 | 🟡 |
| `PageResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistIndexResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistTaxonomyResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 |
| `SearchCollection` | derived | probably none | 🔴 | 🔴 | 🔴 |
| `TaxonomyType` | 🟡 | 🟡 | 🟠 | 🟠 | 🟠 |
| `EntryType` | derived | none | none | 🟠 | ⚪/🟠 |
| `ApiRequestStatus` | derived | none | none | 🔴 | ⚪ |
| API index | derived | none | none | 🔴 | ⚪ |

## 5.2 Daily synchronization and production readiness

| Domain | Daily-sync readiness | Deployment/cutover relevance | Main remaining issue |
|---|---|---|---|
| Programs | 🟡 | core dependency | Adapter works; needs production idempotent sync wrapper |
| Episodes | 🔴 | core dependency | Real identity/source contract still to derive |
| Broadcasts | 🔴 | core dependency | Real extraction plus replay-safe ongoing updates |
| Channels | 🔴 | required | Source/storage model not yet established |
| Posts | 🔴 | required | Full source/contract and update behavior audit |
| Pages | 🔴 | required | New domain for replacement |
| Playlists | 🔴 | required | Source/taxonomy model unknown; major uncertainty |
| Search | 🔴 | required | Depends on completed synchronized resources |
| ConcertPodium / recordings | 🟡 | site-functionality dependency | Must be included although absent from current OpenAPI |

Production synchronization must eventually cover:

- deterministic identity;
- idempotent inserts/updates;
- deletion or unpublishing policy;
- replay-safe episode/broadcast identity;
- transaction boundaries;
- partial-failure recovery;
- safe reruns;
- logging and exit status;
- suspicious-result detection;
- scheduling;
- incremental/high-water-mark behavior where useful.

---

# 6. Existing replacement domains not represented directly by this OpenAPI

The replacement also contains requirements that are not first-class resources in the frozen public API contract.

| Domain | Current coverage | Notes |
|---|---|---|
| Genres | ✅ | Existing schema/migration work |
| Subgenres | 🟡 | Existing schema/source work |
| Artists | 🟡 | Source structures inspected |
| Editors | 🟡 | Source structures inspected |
| Images | 🟡 | Source contracts/builders established |
| Audio/media | 🟡 | Source contracts/builders established |
| ConcertPodium | 🟡 | Replacement schema/source work exists |
| Venues | 🟡 | Replacement schema exists |
| Recording collections | 🟡 | Replacement schema exists |

Completeness must therefore be checked in both directions:

1. **Current API → replacement**
2. **Required site/Salsa functionality → replacement API**

---

# 7. Architectural classification for every API field

Every field found during the resource audits should be classified as one of:

### A. Must migrate/synchronize

Durable source content that must be preserved in Salsa and kept current.

### B. Derive at API time

Values that do not require dedicated storage, for example resource type, links, or locale-specific response formatting.

### C. Existing data, different response shape

The data already exists, but the replacement currently exposes it differently.

### D. Intentionally dropped/redesigned

A deliberate incompatibility. Every such difference must be documented and approved.

### E. Needs real-response verification

The generated OpenAPI contract is ambiguous or malformed. Inspect live responses or application code when possible.

---

# 8. Current audit: `ProgramResource`

## 8.1 Completed real WordPress program adapter

Real-data result:

- 810 historical WordPress program terms
- 373 historical logical programs
- 447 terms referenced by in-scope broadcasts
- 189 logical programs to synchronize/migrate
- 467 historical aliases retained
- 365 localized `program_text` rows

Established identity rules:

- program terms are child `programma_genre` terms;
- historical aliases group transitively by same slug stem OR exact title + locale;
- identity uses the complete historical term population, independent of the 2018 cutoff;
- canonical `program_id` is the lowest historical NL term ID, otherwise lowest EN term ID;
- scope is determined by broadcasts starting on or after `2018-01-01`;
- canonical slug comes from the canonical term's slug stem;
- adapter produces `compat_programs` and `compat_program_terms`;
- `build_programs()`, `build_program_texts()`, and `build_program_term_map()` remain unchanged.

Regression cases include Concertzender Live, Nuove Musiche with broken Polylang pairing, and the Franz Liszt case whose canonical historical term predates 2018.

## 8.2 Field audit

Evidence note: the deployed legacy `ProgramResource.php` composes these links with `ApiRoute::url(...)`; they are response-layer values and do not require durable Salsa storage.

| Field | Current situation | Classification | Decision/status |
|---|---|---|---|
| `id` | covered | same data/shape | keep |
| `type` | absent from storage | derive at API time | derive |
| `title` | replacement emits multilingual object | data exists, shape differs | adapt per `{locale}` |
| `name` | current replacement reuses slug | needs verification | audit |
| `slug` | covered | same data/shape | keep |
| `subtitle` | absent | possible durable gap | audit source/live behavior |
| `description` | data exists as translations | shape differs | adapt per `{locale}` |
| `date` | absent | semantics unclear | audit |
| `genre` | replacement has genres array | structure differs | compatibility decision |
| `genre.color` | not stored | possible durable gap | audit |
| `image` | no program image relation currently | possible durable gap | audit |
| `mood` | not exposed for programs | possible durable/derived gap | audit |
| `taxonomies` | only partially represented | larger API vocabulary | audit every taxonomy type |
| `content` | not exposed by current program SELECT | possible durable gap | audit |
| `links.index` | generated by `ApiRoute::url(...)` | derive at API time | ✅ no Salsa storage needed |
| `links.self` | generated by `ApiRoute::url(...)` from locale + program ID | derive at API time | ✅ no Salsa storage needed |
| `links.episodes` | generated by `ApiRoute::url(...)` from locale + program ID | derive at API time | ✅ no Salsa storage needed |
| `latest_broadcast` | replacement-only | intentional redesign candidate | document decision |

---

# 9. Legacy API availability

The existing API server must not be treated as a reliable project dependency.

The replacement decision includes moving data access away from the current API-server environment and toward WordPress through the replacement compatibility/synchronization layer.

Therefore:

- the frozen OpenAPI specification is the primary published-contract reference;
- WordPress is the primary source for extraction/synchronization analysis;
- existing application/API code can clarify behavior when available;
- live API responses are useful but optional;
- inability to query the legacy API must not block development.

On 2026-08-30, the legacy API temporarily returned HTTP 500 with `errno=28 No space left on device`. After reclaiming server disk space, the endpoint returned HTTP 200 again, but `programs.index` returned an empty data set. Live-response verification therefore remains opportunistic rather than foundational.

---

# 10. Production deployment/cutover

The project may require a new VPS, potentially at Greenhost.

Production readiness may therefore include:

- VPS provisioning;
- Linux/runtime packages;
- web server and application configuration;
- restricted database credentials;
- secrets/configuration management;
- TLS;
- DNS/reverse proxy changes;
- file permissions;
- logging;
- scheduled synchronization;
- backups;
- basic hardening;
- monitoring;
- smoke tests;
- cutover procedure;
- rollback procedure.

This work is part of the production finish line, not an afterthought.

---

# 11. Remaining-work prognosis

Current planning estimate:

- **Optimistic:** 12–14 focused development days
- **Most likely:** 15–20 focused development days
- **Conservative:** 22–27 focused development days
- At the current concentrated-session working pattern: roughly **4–6 calendar weeks**

The planning estimate refers to **production-ready replacement**, not merely “works in development”.

| Workstream | Focused days |
|---|---:|
| API coverage + field-level audit | 1–2 |
| Episode + Broadcast real adapter | 2–4 |
| Media/credits/taxonomy/content completion | 1–2 |
| Channels | 1–2 |
| Posts + Pages | 1–2 |
| Playlists + playlist taxonomies | 2–4 |
| Search | 1–2 |
| ConcertPodium / recording completion | 1–2 |
| Production-grade daily synchronization | 2–4 |
| Performance/index/query-plan work | 1–2 |
| API compatibility/regression testing | 2–3 |
| New VPS + deployment/cutover | 2–4 |

These ranges overlap; summing all maxima would overstate the project duration.

The largest remaining schedule uncertainties are currently:

1. playlists + playlist taxonomy semantics;
2. channels;
3. the production hosting/cutover environment.

---

# 12. Definition of done

The replacement is complete when:

- all 18 current API operations have an explicit replacement decision;
- all 14 OpenAPI schemas have been audited;
- all 10 Resource schemas have field-level coverage;
- every required durable field can be stored and synchronized in Salsa;
- every required WordPress extraction contract is implemented and regression-tested;
- API-only/derived values are identified explicitly;
- intentional incompatibilities are documented;
- Channels, Pages, Playlists and Search have explicit replacement implementations or approved redesigns;
- non-OpenAPI functionality such as ConcertPodium is accounted for;
- daily synchronization is deterministic, idempotent, observable and recoverable;
- query performance is acceptable on production-sized data;
- deployment, scheduling, monitoring, cutover and rollback are prepared;
- no migration or production requirement exists only in chat history.
