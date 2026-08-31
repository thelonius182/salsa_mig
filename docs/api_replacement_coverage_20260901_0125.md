# Master API Replacement Coverage Matrix

## Purpose

This document tracks completeness of the Concertzender CPNM replacement across five separate dimensions:

1. **Published API contract** — what the current API exposes.
2. **Data coverage** — whether the required durable information exists in WordPress or another source and can be represented in Salsa.
3. **API read-contract coverage** — whether stable database views expose the Salsa data that the API team needs, without requiring it to understand migration logic or internal joins.
4. **Synchronization coverage** — whether WordPress → Salsa can run safely as an ongoing production process rather than as a one-time import.
5. **Production readiness** — whether the replacement can be deployed, operated, monitored, and cut over safely.

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

## 5.1 Data, read-contract and API coverage

The API boundary is now explicit:

`Salsa normalized tables → database views → resource serialization → JSON/HTTP API`

The database views are the stable **read contract** owned with the data layer. Resource serialization may be implemented by another team and in another programming language.

| Schema / area | Source data | Salsa storage | Extraction | API database views | Resource serialization | Status |
|---|---|---|---|---|---|---|
| `ProgramResource` | ✅ | ✅ | ✅ | 🚧 design from completed field audit | 🟡 behavior substantially audited | 🟡 |
| `EpisodeResource` | 🟡 | ✅ | 🚧 next | 🔴 not designed | 🟠 | 🚧 |
| `BroadcastResource` | 🟡 | ✅ | 🚧 next | 🔴 not designed | 🟠 | 🚧 |
| `ChannelResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| `PostResource` | 🟡 | ✅ | 🟡 | 🔴 not designed | 🟠 | 🟡 |
| `PostIndexResource` | 🟡 | ✅ | 🟡 | 🔴 not designed | 🟠 | 🟡 |
| `PageResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistIndexResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| `PlaylistTaxonomyResource` | 🟠 audit needed | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| `SearchCollection` | derived from resources | probably none | none | 🔴 search read model not designed | 🔴 | 🔴 |
| `TaxonomyType` | 🟡 | 🟡 | 🟠 | 🟠 needed by resource views | 🟠 | 🟠 |
| `EntryType` | derived | none | none | probably none | 🟠 API vocabulary | ⚪/🟠 |
| `ApiRequestStatus` | derived | none | none | none | 🔴 response-envelope work | ⚪ |
| API index | derived | none | none | none | 🔴 route serialization | ⚪ |

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

## 5.3 API database views as the read contract

Database views are an explicit architecture layer, not an implementation detail.

Their purpose is to prevent the API team from having to infer joins, locale rules, fallback rules, or source-specific semantics from the normalized Salsa schema.

The agreed boundary is:

```text
WordPress
    ↓
compatibility / extraction / synchronization
    ↓
normalized Salsa tables
    ↓
API database views
    ↓
resource serialization
    ↓
JSON / HTTP API
```

Responsibilities:

- **Salsa + view layer:** durable data, joins, locale-specific read shape, stable identifiers, and query performance.
- **API serialization layer:** JSON field names/nesting, defaults, derived URLs/links, response wrappers, pagination, HTTP status and routing.
- **Published contract:** determines what the serializer must emit; the current Laravel resource classes are behavioral reference code, not a required implementation language.

The API team should normally query views rather than internal Salsa tables directly.

For one-to-many or many-to-many relations, prefer separate views instead of one flattened mega-view that causes row multiplication. For PROGRAM, the working design is likely to include a scalar program view plus relation views, for example:

- `api_programs` — one row per `salsa.programs.id` + locale with scalar program fields;
- `api_program_genres` — program/genre rows with localized genre data;
- `api_program_taxonomies` — program/taxonomy rows grouped by taxonomy type;
- media/content may be included in `api_programs` or split into dedicated views if that produces a cleaner or cheaper read contract.

These names are provisional until the first PROGRAM views are implemented.

Every production API view must have:

- a documented grain (for example one row per program + locale);
- explicit input/filter keys;
- deterministic locale/fallback behavior;
- stable column names and semantics;
- indexes on the underlying Salsa joins that support the view;
- representative query-plan/performance tests;
- regression tests against known real-data cases.

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

Every field found during the resource audits should be classified in both the **data/read-contract layer** and the **serialization layer**.

### A. Must migrate/synchronize

Durable source content that must be preserved in normalized Salsa tables and kept current.

### B. Expose through an API database view

Durable or relational data that the API needs should be made available through a stable view/read contract. The serializer should not need to reconstruct internal Salsa joins.

### C. Derive during resource serialization

Values that do not require dedicated storage or view columns, for example resource type, route links, mood SVG/mask URLs, response wrappers, or HTTP-specific formatting.

### D. Existing data, different response shape

The data exists, but the published JSON contract presents it differently. The view should expose clean source values; the serializer performs the final JSON shape transformation.

### E. Intentionally dropped/redesigned

A deliberate incompatibility. Every such difference must be documented and approved.

### F. Needs behavior/source verification

The generated OpenAPI contract is ambiguous or malformed. Inspect application resource code, source data and live responses when useful.

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

Evidence note: the actual API resource classes have now been inspected for `HeaderObject`, `GenreObject`, `ImageObject`, `MoodObject`, `TaxonomiesObject`, `BodyObject`, plus `ProgramResource` link generation. These classes are behavioral reference code for serialization; the new API implementation does not have to use PHP/Laravel.

| JSON field | Actual API behavior | Salsa / source implication | API view/read-contract implication | Serialization responsibility | Status |
|---|---|---|---|---|---|
| `id` | program UUID | `salsa.programs.id` | expose as scalar | copy to JSON | ✅ |
| `type` | `"program"` | no storage needed | no view column required | derive constant | ✅ |
| `title` | localized title, fallback to name | `salsa.program_texts.title` | expose requested locale | copy/fallback | ✅ data path established |
| `name` | same value as `title` in actual serializer | same localized title | no separate durable value required unless later source audit says otherwise | emit same localized value | ✅ behavior resolved |
| `slug` | localized/fallback slug in current API | `salsa.programs.slug` in current replacement design | expose scalar slug | copy | ✅ |
| `subtitle` | subtitle or `""` | source/storage not yet established | expose nullable scalar if durable source exists | default to `""` | 🟠 |
| `description` | description stripped of HTML and trimmed | `salsa.program_texts.description` exists | expose localized description | strip tags/trim if compatibility retained | 🟡 |
| `date` | `published_at` formatted `YYYY-MM-DD`, else `null` | publication-date source semantics still need mapping | expose source date if retained | format as date string | 🟠; OpenAPI is incorrect here |
| `genre` | first associated genre; synthetic General fallback when none | normalized genre relation is appropriate | expose program/genre rows, localized name and color token | choose first; create fallback; map color token to hex | 🟡 |
| `genre.color` | derived from symbolic color token | durable token may need source/storage support | expose color token, not necessarily hex | token → hex | 🟠 |
| `image` | nullable; local path becomes media route URL, external image uses stored URL | program-image relation still needs mapping | expose image id/source/path/url/alt/name/caption needed by serializer | build URL and fallbacks | 🟠 |
| `mood.wave` | durable integer, default `1` | program-level mood source still needs connection | expose nullable/raw primitive | default to `1` | 🟡 concept exists |
| `mood.intensity` | durable integer, default `1` | same | expose nullable/raw primitive | default to `1` | 🟡 concept exists |
| `mood.tempo` | durable integer, default `1` | same | expose nullable/raw primitive | default to `1` | 🟡 concept exists |
| `mood.svg` / `mood.mask` | URLs derived from mood primitives | no storage needed | no view columns required | derive URLs | ✅ API-only |
| `taxonomies` | loaded relation grouped by taxonomy type; item has `id`,`name`,`slug` | broader taxonomy vocabulary only partly covered | separate `api_program_taxonomies`-style relation view is preferred | group rows by type into JSON arrays | 🟠 |
| `content.body` | durable rich content rendered to HTML; render failure → `""` | program content source/storage still needs mapping | expose durable content value | render HTML / fallback | 🟠 |
| `content.blocks` | stored value or `""` | durable content | expose value | copy/default | 🟠 |
| `content.sections` | stored value or `""` | durable content | expose value | copy/default | 🟠 |
| `links.index` | route-generated | no storage needed | no view column required | derive route | ✅ |
| `links.self` | route-generated from locale + program ID | no storage needed | `id` + locale are sufficient | derive route | ✅ |
| `links.episodes` | route-generated from locale + program ID | no storage needed | `id` + locale are sufficient | derive route | ✅ |
| `latest_broadcast` | replacement-only field, absent from published `ProgramResource` | current replacement feature | include only if approved redesign | serialize only if retained | 🟠 design decision |

### 8.3 PROGRAM view handoff

PROGRAM is the first resource for which the data-to-API handoff should be made concrete.

A good first implementation target is:

```text
api_programs
  grain: one row per salsa.programs.id + locale

api_program_genres
  grain: one row per program + genre + locale

api_program_taxonomies
  grain: one row per program + taxonomy + locale
```

The exact columns should be derived from the completed field audit above. The views should expose durable/queryable values; API-only values such as `type`, links, mood SVG/mask URLs and response wrappers remain serializer responsibilities.

The API team's simplest PROGRAM show query should then be structurally equivalent to:

```sql
SELECT *
FROM api_programs
WHERE id = :program_id
  AND locale = :locale;
```

with separate relation-view queries where needed. The API team may implement the JSON serialization in any language as long as it satisfies the agreed contract.

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
- deployment/versioning of API database views;
- database grants that allow the API role to read views without requiring direct access to internal Salsa tables where practical;
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
| API database views + index/query-plan work | 1–2 |
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
- every API resource has an explicit database-view/read-contract design (or a documented reason why no view is needed);
- API views have documented grain, locale behavior, stable columns and representative performance/regression tests;
- the API team can implement resource serialization without reverse-engineering internal Salsa joins;
- API-only/derived values are identified explicitly;
- intentional incompatibilities are documented;
- Channels, Pages, Playlists and Search have explicit replacement implementations or approved redesigns;
- non-OpenAPI functionality such as ConcertPodium is accounted for;
- daily synchronization is deterministic, idempotent, observable and recoverable;
- view/query performance is acceptable on production-sized data;
- deployment, scheduling, monitoring, cutover and rollback are prepared;
- no migration or production requirement exists only in chat history.
