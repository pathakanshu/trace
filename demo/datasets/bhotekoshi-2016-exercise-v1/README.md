# Bhote Koshi 2016 exercise: partial data preview

This branch contains generated fixtures, not merely a specification. All people,
reports, institutions, response activity, and media are fictional. The workload
is a software exercise, not a historical missing-person count. Images are dummy
procedural illustrations authorized for replacement later.

## Access from another computer

From your existing Trace clone, use an isolated worktree:

```sh
git fetch origin codex/test-data
git worktree add --detach ../trace-test-data origin/codex/test-data
cd ../trace-test-data
gh release download bhotekoshi-2016-exercise-v1-preview --repo pathakanshu/trace --pattern '*-assets.zip' --dir /tmp/trace-test-data-assets
python3 tools/test_data/unpack_assets.py /tmp/trace-test-data-assets/bhotekoshi-2016-exercise-v1-assets.zip
```

Python 3.10+ is required for the unpack helper. It checks the ZIP checksum and
all 400 members before writing anything; matching existing files are preserved.
The actual bundle was restored twice into a fresh temporary checkout: both runs
verified 200 images and 200 thumbnails; the second preserved bytes and mtimes.
Ten unpacker regressions cover malformed archives, path escapes and overwrites.
The download URL, SHA-256 and byte count are in `asset-distribution.json`.
GitHub repository access may require authentication. The release also includes
the contact sheet. Binary images are intentionally excluded from Git.

## Contents and integration

- `records/<kind>/part-*.jsonl`: 8,027 normalized records, including 1,150 Person
  records for 1,000 fictional individuals, 32 organizations, 1,800 sources,
  3,600 claims, 200 media records and 170 locations. See `manifest.json` for all
  counts, shard hashes and asset paths.
- `raw/reports/`: 1,800 primary fictional source documents plus two separate
  control reports (`src-900001.json`, `src-900002.json`).
- `context/`: cited historical context, verified current OSM geography and the
  archived geographic input. Current mapping is not a 2016 flood boundary.
- `../../../tests/fixtures/bhotekoshi-2016-exercise-v1/hero/`: the 50-individual
  hero profile (62 Person records), with related record closure. The manifest
  selects 24 media seeds across all five duplicate classes. Repaired closure has
  658 records, including 40 media, 54 locations and the incident. Every selected
  record equals its full-corpus counterpart; no primary record was changed.
- `tests/fixtures/bhotekoshi-2016-exercise-v1/` from repository root: evaluator
  expectations, identity/media families, replay actions and scenarios. Keep these
  private fixtures out of application ingestion, retrieval, prompts and indexes.

An importer still needs to be implemented by the application integration owner.
Read `demo/spec/record-contract.md` and `trace-record.schema.json`. Import only
accepted records and referenced raw documents/assets, preserving stable IDs,
source history, timestamps and unknowns. Resolve references in two passes;
respect `available_at` when replaying checkpoints. Hero records reuse full-corpus
IDs. Do not import hero/oracle manifests as graph records. Human-review actions
are test inputs/expectations, never completed identity decisions. Broader record
kinds need an explicit application mapping; do not silently drop them.

## Actual validation and remaining work

The older `schema-validation.json` and `validation-report.json` cover 19 limited
checks; their zero failures do **not** mean complete contract conformance.
The stricter supplementary `contract-audit.json` reports **18 checks passed,
15 failed, 2 blocked**. All 8,027 primary records pass the catalog JSON Schema,
but 153 references reveal records before their release time. Manifest, license,
checkpoint oracle, replay and validation-report
support shapes differ from the documented contract. The separate 26-record
control pack now passes its file checks. See each rule's measured examples; no application replay was run.

The separate fresh `media-audit.json` reports **9 passed, 0 failed, 1 blocked**:
200 images + 200 thumbnails decoded, 160 unique image hashes, all five family
classes and 36/24/60 base EXIF coverage verified from files. Total actual asset
bytes are 6,022,750. No image was changed. The blocked check is application media
verification; these file checks do not prove crop matching or caption truth.

This audit leaves the catalog, stable IDs, media bundle and previous reports
unchanged. Repair release dependencies and support contracts before building a
complete importer/replay around this preview. Top-level shape checks do not
exhaustively validate nested semantics. The data tools' 110 distinct tests pass across schema and Pillow environments;
its corpus audit intentionally exits 1 for the observed data failures.

- All 1,800 original source hashes match. However, the 1,260 JSON sources use
  a legacy envelope that fails the specified raw-report shape; the 540 text
  sources preserve claim excerpts. Coordinate a versioned conversion before
  relying on the contract-shaped importer. Original source files are unchanged.
- Community checks find 360 self-votes, 120 duplicate voting pairs, 36 task
  submission target mismatches, missing cited review evidence and no hero person
  with two distinct active followers. Existing snapshots are unchanged.
- Geography is 170/1,000: the remaining 830 records require verified geographic
  inputs. The current points reuse four settlement anchors; no approved area
  polygons or historical flood boundary are supplied.
- Private identity rows now match the specified contract, preserving all IDs,
  membership and ages. Initial locations are 50 existing points and 950 unknowns;
  the geography deficit is explicit and no runtime identity decisions are seeded.
- The control pack is under `tests/fixtures/bhotekoshi-2016-exercise-v1/control/`.
  Its two incidents and ten people are outside the primary counts; runtime
  isolation/reset still requires a compatible importer.
- The private query suite contains 40 distinct questions, real claim/source
  citations, time cutoffs and explicit uncertainty. Seven query tests pass; no
  answers were generated or evaluated by the application.
- All 40 private negative cases now have concrete inputs and documented expected
  errors/deltas. Parser/schema/reference/time and image-decoder fixture checks
  ran; retry/injection/unsupported application cases remain unexecuted. See
  `tools/test_data/README.md` for runner semantics and separate Pillow checks.
  The full evaluation suite is unfinished.
- Identity benchmark labels/coverage pass, but all 20 same-name/age negatives
  have indistinguishable cited context. They need distinguishing sourced evidence
  before being used to score a context-based rejection. No review was executed.
- The hero selection is reference-closed, but its twelve story plans are not
  executable. Some focal IDs do not match the narrative (treatment vs shelter,
  comments vs correction/translation); scenario semantics still need repair.
- The 80 planned confirmations contain two cyclic/redundant edges, giving 78
  distinct planned joins and 1,072 groups instead of 1,070. No review ran.
- Checkpoint oracle rows are specified targets, not executed observations.
  Fixture-only recomputation finds T+72 counts 353 missing / 547 safe / 50 injured
  / 50 unresolved, versus required 650 / 250 / 50 / 50. Another check finds six
  death rumors without the required equal-time or undated opposing status when
  released. These are generator defects; no application decision was executed.
  Published sources remain unchanged pending a coordinated, versioned repair.
- No importer, application replay, reset, alert, identity-resolution, agent trace,
  or UI asset-loading behavior was verified for this corpus. In particular,
  **reset is not confirmed working for this dataset**.
- The optional video pack is deferred. Media are dummy assets, not photographs
  or evidence of the historical event.

To rerun data checks, use Python 3.10+ with Pillow and jsonschema available in a
separate tooling environment (no application dependency changes are required):

```sh
python3 tools/test_data/schema_check.py
# Strict supplementary audit (currently exits 1 for genuine corpus failures):
python3 tools/test_data/audit_contracts.py
python3 -m unittest discover -s tools/test_data -p 'test_*.py'
# In a separate Pillow-equipped Python if needed:
python3 -m unittest discover -s tools/test_data -p '*media*.py'
python3 tools/test_data/audit_media.py
```

Run these after restoring media. The strict audit does not regenerate fixtures;
its failed/blocked checks describe real limits. The historical legacy validator
rewrites derived outputs and is not the recommended conformance gate; it now
refuses cached schema results when jsonschema is missing. Generation/repair
constraints are documented in `tools/test_data/README.md`.

For a concrete repair/integration handoff, read the private
`tests/fixtures/bhotekoshi-2016-exercise-v1/REPAIR_PLAN.md` from repository root.
Corpus-wide repair needs an explicit immutable-source/versioning decision before
changing already distributed inputs. Keep that guidance outside application data.
