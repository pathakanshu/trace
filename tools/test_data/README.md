# Exercise data tools

Work only in a dedicated test-data checkout. Python 3.10+ is recommended;
Pillow is needed for assets/semantic validation and jsonschema for schema checks.
These are tooling requirements, not application dependency changes.

The current generated snapshot is checked in. To consume it, follow
`demo/datasets/bhotekoshi-2016-exercise-v1/README.md`; do not regenerate assets
because the distributed manifest pins their exact bytes.

Historical generation sequence (not a complete/correct repair path; see the
private REPAIR_PLAN before regenerating distributed inputs):

1. `python3 tools/test_data/allocate_ids.py`
2. `python3 tools/test_data/prepare_context.py` (uses archived verified OSM input)
3. `python3 tools/test_data/generate_assets.py` (fresh asset directory only)
4. `python3 tools/test_data/generate_catalog.py`
5. `python3 tools/test_data/schema_check.py`
6. `python3 tools/test_data/validate_dataset.py`

`unpack_assets.py <zip>` restores the published media with checksum checks.
The snapshot includes manually curated media-family scenario tags; a fresh asset
regeneration does not preserve these curation edits. Reconcile the private
family oracle and distribution checksum before publishing regenerated media.
The location quota and evaluation suite remain incomplete; see the dataset
README. None of these tools imports records into the running application.

## Supplementary contract audit

`python3 tools/test_data/audit_contracts.py` reads the existing corpus without
regenerating records, touching assets, or importing app/runtime modules. It
checks all primary records against the actual catalog schema, support-file
closed top-level shapes, ID/reference/incident/release closure, lifecycle times,
and the control-pack presence/count/schema. Dates are parsed, unknown observation
times stay unknown, and actual media creation dates are separate from 2016.

`--output demo/datasets/bhotekoshi-2016-exercise-v1/contract-audit.json` saves
measured results using the specification's validation-report shape. Exit 1 means
observed failures, 2 means blocked checks without observed failures, and 0 means
only these implemented checks passed. It never certifies geography, live replay,
model results, or all nested supporting semantics. Unlike the legacy validator,
it does not fall back to a stale schema report when jsonschema is unavailable.

Run its own offline checks with:
`python3 -m unittest discover -s tools/test_data -p test_contract_audit.py`.
The current corpus audit has 24 pass / 15 fail / 2 blocked; failures are intentional
findings in the partial dataset, not successful runtime behavior.

## Isolated control pack

`python3 tools/test_data/generate_controls.py` creates only the 26 control records
and their two original source documents. It never regenerates primary records or
assets. IDs are reserved from 900001; names/reference text deliberately collide
across incident/publisher scopes. The generator preflights every destination,
refuses differing existing content or escaping paths, and leaves identical files
untouched. There is no runtime import or reset call.

Run the tooling checks with
`python3 -m unittest discover -s tools/test_data -p 'test_*.py'`.
The tests include saved-source tampering, malformed control rows, exact schema
and counts, reference/release isolation, raw hash/excerpt checks, collision scopes,
idempotent generation and refusal to overwrite different files or escape root.

## Private research queries

`python3 tools/test_data/generate_queries.py` writes 40 held-out questions with
real catalog claim/source citations and explicit time cutoffs, uncertainty and
forbidden conclusions. The category quotas are 10 person, 8 geographic access,
8 aid/facility, 8 media lineage and 6 insufficient-evidence questions. Baseline
questions cannot cite later reports. Queries use public evidence only; hidden
identity/media-family answers are never read by this generator. No model answer
or verification result is generated. Keep queries out of application inputs.

Seven query tests check deterministic generation, exact contract/category counts,
real citation closure, cutoff isolation, both media publication contexts, missing
inputs and rejected extra result fields. The old `qry-*` placeholders were not
contract IDs; the suite now uses `query-000001` through `query-000040`.

## Checkpoint fixture diagnostics

The audit recomputes private identity cohorts from visible claims at each cutoff.
It combines latest known observation-time statuses with undated competing claims;
all exercise death rumors remain unresolved. This is a fixture design check, not
application summary logic or a completed human identity review. A separate rule
requires equal-time or unknown-time opposing evidence for every death rumor.

Measured T+72 counts are 353 missing / 547 safe / 50 injured / 50 unresolved,
against targets 650 / 250 / 50 / 50. Earlier cohorts match under this method.
The published generator snapshot assigned 297 additional safe follow-ups outside
the intended safe cohort. The candidate generator fix is tested only in temporary
output; the distributed source records have not been regenerated. Six death rumors also lack the specified temporal opposition when
released. Do not rerun generation to silently rewrite published source history;
coordinate a versioned repair and recompute hashes/hero closure before release.
Seven regression tests cover ordering, unknown/equal times, future-source cutoff,
identity partitioning and these actual partial-corpus defects.

## Private negative inputs

`python3 tools/test_data/generate_invalid.py` replaces the 40 `bad-*` placeholders
with contract-shaped `case-000001` through `case-000040`, eight per category:
malformed/missing, bad/cross-incident references, time/semantic errors, media
path/size errors, and retry/prompt-injection/unsupported-format procedures.

The checked-in file is tested directly, then compared with deterministic generator
output. Parser, schema, reference and chronology tests prove the intended faults;
valid baseline records are checked first. Missing/traversal/absolute asset paths
are intentional **negative inputs**, never proposed files in the accepted corpus.
Traversal/absolute paths are rejected lexically and are never opened. Oversize
uses 1,025 real bytes against an explicit 1,024-byte test configuration, not a
claim about the app's production upload limit. Embedded byte strings include a
real 1x1 PNG control and a truncated derivative. They remain outside the 200-image
corpus and do not require a new binary bundle.

`input` objects with `procedure`, `setup` and `repeat_count` are fixture-runner
plans, not application endpoint payloads. A future compatible adapter must run
setup before measuring the expected zero delta for retries. Prompt-injection
cases use analysis without publishing: hostile text stays source data. None of
these eight runtime cases has run; no agent response or success is prefilled.
No nonexistent replay-action IDs are used as prerequisites.

Actual tooling results: **184 distinct tests pass across two environments**.
The schema environment runs 169 and explicitly skips fifteen Pillow tests. Run the
fifteen media checks with a Pillow-equipped tooling Python:
`python3 -m unittest discover -s tools/test_data -p '*media*.py'`.
That separate run passes all fifteen. Do not count skipped decoder checks as passes
when only one environment is available. No application dependency was added.

## Immutable raw-source audit

All 1,800 public source files have measured matching SHA-256 and UTF-8 bytes.
All 3,600 claims were associated with their source. The 540 plain-text reports
preserve their excerpts. The **1,260 structured JSON reports fail the specified
raw-envelope shape**: they use the older `fictional_exercise_record/title/claims`
layout instead of the contract's publisher/reference/original_content/entries.
The strict audit now reports that mismatch; a matching hash alone is not enough.
Five tests cover valid control envelopes, changed bytes, valid hashes on invalid
envelopes, incorrect locators, escaping symlinks and the actual legacy corpus.
No source bytes, recorded hashes or claims are repaired by this audit.

## Asset restore rehearsal and failure checks

The unpack helper now validates declared/uncompressed sizes before decoding ZIP
members, rejects duplicate inventories and archive symlinks, confines paths even
when the asset root itself is a symlink, preflights existing files/parents, and
uses exclusive file creation. It refuses changed existing assets. Ten tests cover
success/idempotence, checksums, inventory, member sizes, path/symlink escapes,
non-file destinations, overwrite prevention and the 250 MiB primary budget.
Preflight is not a transaction against concurrent filesystem changes; restore into
an idle checkout. Optional video packs are outside this helper.

The actual published bundle was restored twice into a fresh temporary checkout:
400 files (200 images + 200 thumbnails) verified each time, with all bytes and
modification times preserved on the second run. Measured ZIP SHA-256 remains
`00629b3cc4b832e092f206b54f15c57d438e124dfaca97b904b4c1a21d8a444b`.
No application or database was loaded, and the distributed bundle is unchanged.

## Hero selection and closure

`python3 tools/test_data/generate_hero.py` selects existing public records by the
stable hero allocation and story focal IDs, then follows every explicit catalog
reference. Included Person records pull their claims; included sources pull all
claims in that report. An organization's inclusion does not pull every publication.
The former exporter omitted incident references and misread facility/aid fields.
The repaired selection adds `inc-000001`, `loc-000841` and `loc-000925`, all copied
unchanged from the full catalog, and sorts rows deterministically.

The saved profile now contains **658 records**, including 50 hidden individuals,
62 Person records, 304 claims, 125 sources, 40 media and 54 locations. It has no
missing/cross-incident/future references and all saved objects equal full-catalog
objects. Eight tests cover saved closure/quotas, deterministic order, missing
inputs, altered/duplicate records, typed correction links, idempotent export and
symlink confinement. The legacy validator delegates hero export to this tool.

This fixes reference closure only. The twelve named story plans still require
semantic repair and executable actions: for example, the shelter story points to
a treatment facility, and the correction/translation stories point to comments.
The manifest's scenario IDs are planned coverage, never proof of story execution.

## Community semantics and repair handoff

The supplementary audit now checks self/duplicate votes, task/submission targets,
review evidence/times, and subscription uniqueness/coverage. Actual defects are
360 self-votes, 120 duplicate voting pairs, 36 task target mismatches and no hero
Person with two distinct active followers. Six tests include valid counterexamples,
independent failure modes and the actual partial-corpus characterization.
No community records, votes, reviews or subscriptions are mutated by this audit.

`tests/fixtures/bhotekoshi-2016-exercise-v1/REPAIR_PLAN.md` gives measured defects,
reusable artifacts, immutable-source/versioning decisions and the integration
sequence for the app owner. It is private developer guidance, never app input.

The shared catalog reader used by query/negative/hero generators now rejects
repeated IDs (including across shards), duplicate JSON object keys, NaN/Infinity,
blank/nonobject rows, invalid UTF-8, missing final newlines and symlink escapes.
Seven input-boundary tests verify rejection before any fixture generation;
valid Unicode and null unknown values are preserved. Strict JSONL audit parsing
also rejects repeated object keys, so malformed input cannot hide behind a
last-key-wins decoder. Existing public rows remain unchanged.

## Contract-shaped private identities

`python3 tools/test_data/generate_identities.py` preserves all 1,000 allocated
private IDs, person membership, primary record choices and canonical ages, while
writing the exact identity-oracle contract. It derives the initial location only
from the existing initial MISSING claim: 50 point locations and 950 unknowns.
Clusters use the cited context feature labels already attached to those points;
no coordinates or absent reporting zones are invented. This does not fulfill the
geographic coverage quota. Public records and source history are unchanged.

Seven tests verify the saved shape, all-person partition, age/multiplicity quotas,
stable allocation, unknown geography, missing evidence, unsupported clusters and
rejected fabricated/extra decision fields. Three additional writer tests cover
repeat byte/mtime preservation, rejected escaping paths and non-finite output.
Query/negative/identity writers share this confined idempotent output routine.
The generator hookup now preserves these contract-shaped private identities.

## Held-out identity benchmark evidence

The 250 pair IDs are unique and enumerate all 165 positive combinations plus
85 negatives; labels match private membership, citations resolve, and 20 negatives
share a known name and age. However, all 20 have identical supplied descriptions,
assertions, observation times and geographic geometry. Different Source/Person/
Location IDs alone do not distinguish identities. They cannot support the intended
context-based rejection scenario as authored. The audit reports this defect.
Seven tests cover correct coverage, flipped labels, reversed duplicates, missing
positive pairs/citations and identical versus changed contextual input. This is
an exact-context diagnostic; different wording is not proof of distinguishability.
No actual identity review or resolver result was generated.

## Replay-plan arithmetic and legacy validator guard

The 80 planned confirmations contain two redundant triangle edges (`act-000011`
and `act-000014`), so they imply 78 distinct joins and 1,072 groups rather than
80 joins / 1,070 groups. The strict audit now fails this fixture-plan constraint.
Five tests cover acyclic joins, rejected-pair non-merging, triangles, label errors,
invalid pairs and the legacy plan. These are planned counts, not runtime results.

The legacy validator no longer falls back to cached `schema-validation.json`
when jsonschema is unavailable. It exits 2 before checking or writing outputs.
A unit regression covers that early guard. An actual run in the separate Pillow
runtime (which lacks jsonschema) returned the expected blocked result; hashes and
mtimes of all 1,903 dataset files remained identical. That run is **not** a passed
schema/media validation. Prefer the read-only strict audit for current conformance;
legacy generation/export routines still use incomplete support formats.

## Fresh read-only media audit

In a Pillow-equipped tooling environment, run:
`python3 tools/test_data/audit_media.py`.
`--output demo/datasets/bhotekoshi-2016-exercise-v1/media-audit.json` saves only
measured validation results. Exit 2 means the implemented file checks passed but
application verification is blocked; it is not a successful EvidenceWalker run.

Actual run: Pillow 12.3.0 / Python 3.12.14, **11 pass / 0 fail / 1 blocked**.
Decoded all 200 images and 200 thumbnails; actual SHA-256/bytes/dimensions/MIME
match the catalog and manifest. There are 160 distinct image hashes, 120 disjoint
families (40 exact, 20 resize, 10 reencode, 10 crop, 40 singleton), 36 GPS/24
non-GPS EXIF/60 no-EXIF bases, ten reciprocal singleton negative pairs and five
earlier-publication-arrives-later cases. Original plus thumbnail bytes total
6,022,750, below 250 MiB. All base long edges and 320px thumbnails meet bounds.

Checks establish exact-byte copies, recipe geometry, EXIF presence and file
integrity. A further in-memory check reproduces all 40 derivative hashes exactly
(20 resizes, 10 reencodings, 10 crops) using the committed generator recipe and
Pillow/encoder version; resize JPEG quality 86 and optimize=True are explicit
source-code defaults. No asset is written. This does not establish general
near-copy detection performance, caption truth, geolocation, authenticity, human
visual similarity or an application verification result. Twelve media-auditor
unit tests run alongside the three negative-decoder tests in the Pillow suite.
No image or thumbnail was modified.

## Archived geography consistency

The strict audit now checks the actual preserved OSM gzip hash, source element
IDs/version/epoch, closed context properties and point/line coordinates. All five
context features match eight archived node/way elements. All 170 existing
locations match their cited settlement anchors, but reuse only **four distinct
coordinates**. No new locations or coordinates were generated.

Seven tests cover real archived input, altered coordinates/hashes/versions,
unknown references, escaping symlinks, invalid positions and preserving separate
river segments. These are archive-consistency checks. They do not establish
2016 geography, a historical flood boundary, country/district geofencing, terrain
suitability or approved inhabited sampling zones; geographic completion stays
blocked at 170/1,000. Declared country metadata agreement is not a boundary test.

## Public input boundary

The strict audit scans all 8,027 catalog records and 1,800 original reports for
private identity/family labels, evaluator IDs and prefilled runtime-result fields.
All 400 media/thumbnail paths stay inside the public asset directory; source
paths stay inside raw/reports. Traversal and symlink escapes into private fixtures
are rejected before a file is read. No private oracle files are opened by this
check. Six tests cover nested markers, actual inputs, confined paths, symlinks,
byte preservation and treating hostile instructions as inert source text.

This is a static fixture audit, not an application authorization, prompt-injection
or retrieval-isolation test. It detects the enumerated marker fields, not every
possible encoded disclosure. Actual importer/model boundaries remain untested.

## Clean-clone handoff rehearsal

A fresh shallow clone from origin/codex/test-data at b77e59d, with a fresh GitHub
release download, passed all 119 then-current tests. Both fresh audits reproduced
the published checks exactly (excluding run timestamps): contract 20/15/2 and
media 10/0/1. Bundle restore verified all 400 files and the documented SHA-256;
tracked files stayed clean and no .jac runtime store was created. This was a
fresh checkout on the same laptop, not a second-laptop application rehearsal.

The first creation-provenance check exposed 200 mismatched timestamps. The
catalog generator incorrectly used its own run time (07:06Z); `generate_assets.py`
records the asset operation's start as STAMP in asset-measurements.json
(2026-09-27T00:42:47Z). The catalog generator now uses that original receipt.
This is a recorded batch-operation start, not per-file capture time, a copied
filesystem mtime, or a new audit timestamp. Original encoder version is unrecorded.

`python3 tools/test_data/repair_media_time.py` preflights without writes; `--write`
corrects only the known mistaken timestamp, exact hero copies and affected
manifest shard hashes. It requires receipt/catalog property agreement, verifies
all 400 actual asset hashes, and rejects unexpected timestamps, stale manifests,
changed hero copies or escaping paths. All destinations are preflighted before
individual atomic replacements; concurrent edits are unsupported.

Actual repair: 200 catalog rows, 40 hero copies, four files. All other primary
fields and 1,800 raw reports remain byte-preserved; binary inventory and ZIP hash
are unchanged. A repeat verified 400 assets and changed zero files. Nine tests
cover input preservation, provenance, preflight failures, hash/hero refresh,
symlink rejection, idempotence and the original generator regression. The separate
media audit now passes all eleven implemented checks; application evidence remains
blocked. No historic generator version is inferred from the current Pillow version.

## Fresh catalog quota coverage

The strict audit recomputes 25 exact/minimum coverage dimensions directly from
current catalog records: primary counts, publisher and subject types, report
formats/cardinality/dependency declarations, facility/infrastructure/hazard/aid
types, community/task/investigation/subscription types and media references.
24 dimensions pass; primary counts fail solely because locations are 170/1,000.
Every organization has at least 43 reports (minimum 15); 70 Nepali contributions
have nonblank English renderings, 200 uploads are cited, 60 claims cite two or
more uploads and 100 cite exactly one. Eight mutation regressions cover these
counts and boundary cases. No private targets or cached reports supply counts.

These counts do not imply correct voting, translation quality, source
independence, geographic placement or story semantics. No-dependency declarations
are counted for fixture coverage, never treated as independent corroboration.

## Publication scopes and lineage DAGs

All 1,800 publication references are unique within their incident/typed-publisher
scope; publisher types and dependency disclosures agree. All 450 declared source
lineage edges form a DAG. Topological checking does not assume numeric ID order
means chronology. Claim correction edges are also checked, but the current
corpus has zero such edges; that pass does not supply correction-story coverage.
Eight tests cover cycles/self-links/duplicates/missing endpoints, long chains,
scoped reference reuse, publisher types, disclosures and input preservation.
This is fixture validation, not runtime retry/ingestion or independent-source proof.

## Per-Media license inventory

`python3 tools/test_data/generate_licenses.py` writes the specified closed license
shape: 200 entries, one per Media, 120 generated and 80 derived. It preserves
the original usage basis verbatim and the existing shared lic-000001 reference.
Each entry has its catalog hash and recorded asset-run start. Original encoder
version is explicitly "not recorded"; current audit versions are not backfilled
as generation history. No private family IDs, parent IDs or recipes are emitted.

The writer verifies actual image bytes before mutation, rejects changed terms,
checks all family/receipt membership, confines paths and preserves repeated
bytes/mtime. The real second run changed zero files. Eight tests cover saved
shape/content, unknown versions, altered rights/hashes, provenance, missing or
duplicate members, symlinks, corrupted assets and idempotence. The strict audit
checks nested license consistency; the legacy validator delegates to this writer
so it cannot silently restore the old one-row shape. No new rights are granted.

## Candidate cohort repair, not a rewritten release

The generator now keeps all 300 extra FOUND_SAFE depth reports inside the intended
250-person safe cohort. Its ten death rumors retain T+23 observation times that
match existing opposing claims; later arrival is kept separate. In temporary
folders, 1,800 sources / 3,600 claims pass all seven checkpoint targets, all ten
rumor-opposition checks, exact type/cardinality quotas, catalog schema, source
hashes, allocated ID bindings and deterministic second generation. Nine tests
also verify all published raw reports remain unchanged. No application ran.

The main generator now refuses a nonempty records or raw/reports output directory
before loading or writing. This prevents silently replacing the distributed
preview. Coordinate the namespace/version/source migration before adopting any
new corpus; these two fixes do not resolve the other documented generation bugs.
The delivered audit still correctly fails the old final cohorts and six rumors.

The candidate source generator now emits the exact raw-report envelope with
publisher/reference/language/publication text, original_content and entries.
Claims use entries[n] locators for JSON or actual line numbers for pasted text.
Unknown observation times and locations remain null; every original excerpt
resolves. Three additional temporary-output tests pass all 1,800 source integrity
and envelope checks (1,260 JSON / 540 text, 3,600 claims), verify entry labels and
unknowns, and resolve every text locator. Checkpoint/type/cardinality/schema and
determinism regressions still pass. Published raw inputs remain the legacy
format until the coordinated versioned migration; no importer was implemented.

## Candidate vote and follower repair

Candidate generation now allocates 360 unique non-author voting pairs, retaining
240 HELPFUL / 120 NOT_HELPFUL votes and at least one vote per contribution. Vote
times are no earlier than the referenced submission. One hero Person now has two
distinct active followers at baseline, while total/subtype subscription quotas
and people with no followers are preserved. Seven tests verify schema, stable
IDs, timing, distinct voters, follow coverage, deterministic repeats and rejection
of missing/duplicate actors. These are generated fictional workflow inputs, not
executed votes, subscriptions or alerts. The published snapshots still contain
the known self-vote/duplicate/follower defects and still require a coordinated versioned replacement.

Candidate task snapshots now select matching typed contributions, align target
and assignee, cite the actual submission source's claims, use distinct reviewers
with reviewer roles, and keep creation/submission/review/release times ordered.
Contributions wait for cited sources; media subscriptions wait for their targets.
Person followers needed for the hero remain active at T+12. Replacing only these
candidate workflow objects in a read-only structural check removes all 153 forward
references and passes lifecycle checks. Three additional regressions verify this,
exact task quotas, schema and missing-reviewer rejection. No task was executed,
no fixture review establishes truth, and the delivered snapshot is unchanged.
