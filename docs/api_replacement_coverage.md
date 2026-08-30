# Master API Replacement Coverage Matrix

## Purpose

This document tracks replacement coverage for the current Concertzender API.

It is intended to answer, for every existing API operation and schema:

1. What does the current public API expose?
2. Is the required source data available in WordPress or another source system?
3. Can the Salsa replacement schema store that information?
4. Is extraction/migration implemented?
5. Can the replacement API reproduce the required response contract?
6. If the replacement intentionally differs from the current API, has that difference been explicitly accepted?

This document is the migration/API **definition-of-done checklist** and should be updated as each domain is audited.

---

## API baseline

Source:

* Concertzender public API documentation
* OpenAPI version: `3.1.0`
* API/document version: `0.0.1`
* Base server: `https://api.concertzender.nl/api/v1`

Baseline inventory:

* **18 API paths**
* **18 API operations**
* **14 component schemas**
* **10 `*Resource` schemas**
* **1 reusable response schema**

The current API description states that the API provides access to:

* articles/posts
* programs
* episodes
* channels
* media
* broadcasts

and that endpoints support localization through the `{locale}` parameter.

---

## Status definitions

| Status          | Meaning                                                                        |
| --------------- | ------------------------------------------------------------------------------ |
| ✅ Covered       | Required data, storage, migration and/or API behavior are sufficiently covered |
| 🟡 Partial      | Substantial coverage exists, but work or verification remains                  |
| 🟠 Audit needed | Related structures exist, but contract mapping has not yet been established    |
| 🔴 Missing      | No adequate replacement coverage currently exists                              |
| ⚪ API-only      | Does not require migration/storage and can be produced by the API layer        |
| 🚧 In progress  | Currently being investigated or implemented                                    |

---

# 1. API operation inventory

| Area      | Operation                           | Method/path                                     | Main response                |
| --------- | ----------------------------------- | ----------------------------------------------- | ---------------------------- |
| Broadcast | `broadcasts.index`                  | `GET /{locale}/broadcasts/{date}`               | `BroadcastResource[]`        |
| Channel   | `channels.index`                    | `GET /{locale}/channels`                        | `ChannelResource[]`          |
| Channel   | `channels.show`                     | `GET /{locale}/channels/{id}`                   | needs verification           |
| Episode   | `episodes.index`                    | `GET /{locale}/episodes`                        | `EpisodeResource[]`          |
| Episode   | `episodes.show`                     | `GET /{locale}/episodes/{id}`                   | `EpisodeResource`            |
| Index     | `index`                             | `GET /{locale}`                                 | endpoint directory           |
| Page      | `pages.index`                       | `GET /{locale}/pages`                           | `PageResource[]`             |
| Playlist  | `playlists.index`                   | `GET /{locale}/playlists`                       | `PlaylistIndexResource[]`    |
| Playlist  | `playlists.show`                    | `GET /{locale}/playlists/{id}`                  | `PlaylistResource`           |
| Playlist  | `playlists.taxonomy.index`          | `GET /{locale}/playlists/{taxonomyType}/index`  | `PlaylistTaxonomyResource[]` |
| Playlist  | `playlists.taxonomy.playlist.index` | `GET /{locale}/playlists/taxonomy/{taxonomyId}` | `PlaylistIndexResource[]`    |
| Post      | `posts.index`                       | `GET /{locale}/posts`                           | `PostIndexResource[]`        |
| Post      | `posts.show`                        | `GET /{locale}/posts/{id}`                      | `PostResource`               |
| Program   | `programs.index`                    | `GET /{locale}/programs`                        | `ProgramResource[]`          |
| Program   | `programs.show`                     | `GET /{locale}/programs/{id}`                   | `ProgramResource`            |
| Program   | `programs.episodes.index`           | `GET /{locale}/programs/{id}/episodes`          | `EpisodeResource[]`          |
| Search    | `search`                            | `GET /{locale}/search/{query}`                  | `SearchCollection`           |
| Search    | `search.type`                       | `GET /{locale}/search/{entryType}/{query}`      | `SearchCollection`           |

---

# 2. OpenAPI schema inventory

## Resource schemas

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

## Supporting schemas

11. `ApiRequestStatus`
12. `EntryType`
13. `SearchCollection`
14. `TaxonomyType`

## Reusable responses

* `ModelNotFoundException`

---

# 3. Master replacement coverage matrix

| API domain / schema        | Data available | Salsa storage                 | Migration / extraction | Replacement API contract | Status | Notes                                                                                           |
| -------------------------- | -------------- | ----------------------------- | ---------------------- | ------------------------ | ------ | ----------------------------------------------------------------------------------------------- |
| `ProgramResource`          | ✅              | ✅                             | ✅                      | 🟡 audit in progress     | 🟡     | Real WordPress compatibility adapter completed; contract-level audit now in progress            |
| `EpisodeResource`          | 🟡             | ✅                             | 🚧                     | 🟠                       | 🟡     | Real WordPress extraction contract is the next migration implementation phase                   |
| `BroadcastResource`        | 🟡             | ✅                             | 🚧                     | 🟠                       | 🟡     | Replay invariant established: replay creates another broadcast referencing the original episode |
| `ChannelResource`          | ❌ audit needed | ❌                             | ❌                      | ❌                        | 🔴     | Theme channels were previously missing from the migration checklist                             |
| `PostResource`             | 🟡             | ✅                             | 🟡                     | 🟠                       | 🟡     | Source and builders exist; full API contract audit still required                               |
| `PostIndexResource`        | 🟡             | ✅                             | 🟡                     | 🟠                       | 🟡     | Likely same domain data as `PostResource`, with cheaper list rendering                          |
| `PageResource`             | ❌ audit needed | ❌                             | ❌                      | ❌                        | 🔴     | Not yet represented in replacement migration/schema work                                        |
| `PlaylistResource`         | ❌ audit needed | ❌                             | ❌                      | ❌                        | 🔴     | Not yet represented                                                                             |
| `PlaylistIndexResource`    | ❌ audit needed | ❌                             | ❌                      | ❌                        | 🔴     | Not yet represented                                                                             |
| `PlaylistTaxonomyResource` | ❌ audit needed | ❌                             | ❌                      | ❌                        | 🔴     | Requires taxonomy and playlist audit                                                            |
| `SearchCollection`         | derived        | probably no dedicated storage | ❌                      | ❌                        | 🔴     | Search should probably be built over replacement resources rather than migrated as data         |
| `TaxonomyType`             | 🟡             | 🟡                            | 🟠                     | 🟠                       | 🟠     | Existing Salsa taxonomy coverage is incomplete relative to API taxonomy vocabulary              |
| `EntryType`                | derived        | none required                 | none required          | 🟠                       | ⚪/🟠   | Primarily API/application vocabulary                                                            |
| `ApiRequestStatus`         | derived        | none required                 | none required          | ❌                        | ⚪      | API response wrapper concern                                                                    |
| API index                  | derived        | none required                 | none required          | ❌                        | ⚪      | Can be generated from application routes                                                        |

---

# 4. Existing migration domains not represented directly by this OpenAPI

The replacement project also contains domains that are not exposed as first-class resources in the current OpenAPI document.

These must not be lost merely because they are absent from the API specification.

Known examples:

| Domain                | Replacement coverage | Notes                                 |
| --------------------- | -------------------- | ------------------------------------- |
| Genres                | ✅                    | Existing migration/schema work        |
| Subgenres             | 🟡                   | Existing schema/source work           |
| Artists               | 🟡                   | Source structures inspected           |
| Editors               | 🟡                   | Source structures inspected           |
| Images                | 🟡                   | Source contracts/builders established |
| Audio/media           | 🟡                   | Source contracts/builders established |
| ConcertPodium         | 🟡                   | Replacement schema/source work exists |
| Venues                | 🟡                   | Replacement schema exists             |
| Recording collections | 🟡                   | Replacement schema exists             |

This means migration completeness must be checked in **both directions**:

1. Current API → Salsa replacement
2. Required Salsa/site functionality → replacement API

---

# 5. Important architectural distinction

For every API field we audit, classify it into one of these categories:

### A. Must migrate

The value represents durable source content that must be preserved in Salsa.

Examples may include:

* titles
* descriptions
* taxonomy relationships
* media relationships
* channel configuration

### B. Derive at API time

The value does not need dedicated storage because it can be deterministically derived.

Examples:

* resource `type`
* `links.self`
* `links.index`
* localized response shape from normalized translation tables

### C. Existing data, different response shape

The replacement stores the necessary information but currently exposes it differently from the existing API.

This is an API compatibility issue, not necessarily a migration issue.

### D. Intentionally dropped or redesigned

The old API contract is deliberately not reproduced.

Every such difference must be explicitly documented and approved rather than occurring accidentally.

### E. Needs real-response verification

The generated OpenAPI documentation is ambiguous or appears malformed, so a real production API response must be inspected before making migration/schema decisions.

---

# 6. Current audit: `ProgramResource`

Status: **in progress**

The real WordPress program compatibility adapter is complete.

Current real-data migration results:

* 810 historical WordPress program terms
* 373 historical logical programs
* 447 terms referenced by in-scope broadcasts
* 189 logical programs to migrate
* 467 historical aliases retained
* 365 localized `program_text` rows

Established program identity rules:

* program terms are child `programma_genre` terms;
* historical aliases are grouped transitively by same slug stem OR exact title + locale;
* identity uses the complete historical term population, independent of the migration cutoff;
* canonical `program_id` is the lowest historical NL term ID, otherwise the lowest EN term ID;
* migration scope is determined by broadcasts starting on or after `2018-01-01`;
* canonical slug comes from the canonical term's slug stem;
* compatibility adapter produces `compat_programs` and `compat_program_terms`;
* existing `build_programs()`, `build_program_texts()`, and `build_program_term_map()` remain unchanged.

Regression cases include:

* Concertzender Live
* Nuove Musiche with broken Polylang pairing
* Franz Liszt, where the canonical historical term predates 2018

## `ProgramResource` contract audit

To be completed field by field.

Initial categories to verify against real API responses:

* `id`
* `type`
* `title`
* `name`
* `slug`
* `subtitle`
* `description`
* `date`
* `genre`
* `image`
* `mood`
* `taxonomies`
* `content`
* `links`

For each field, record:

| Field | Current API value | Source | Salsa storage | Migration coverage | Replacement API | Decision |
| ----- | ----------------- | ------ | ------------- | ------------------ | --------------- | -------- |
|       |                   |        |               |                    |                 |          |

---

# 7. Known OpenAPI documentation caveats

Do not assume every generated OpenAPI detail is correct without verification.

Known examples:

* `channels.show` currently documents its successful response as a plain string rather than a `ChannelResource`.
* Some resources contain malformed/anonymous properties around nullable `image` or `media` structures.

Where documentation and real responses disagree, record both and decide which behavior the replacement API should preserve.

---

# 8. Definition of done

The API replacement audit is complete when:

* all 18 current API operations have a documented replacement decision;
* all 14 OpenAPI schemas have been audited;
* all 10 Resource schemas have field-level coverage;
* every durable source field required by the replacement is represented in Salsa;
* every required source extraction contract is implemented and regression-tested;
* API-only/derived values are identified explicitly;
* intentional incompatibilities are documented;
* channels, pages, playlists and search have explicit replacement decisions;
* non-OpenAPI replacement domains such as ConcertPodium are also accounted for;
* no migration requirement exists only in chat history.
