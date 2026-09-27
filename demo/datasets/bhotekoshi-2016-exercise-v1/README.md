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
  selects 24 media seeds across all five duplicate classes; closure has 40 media.
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
The stricter supplementary `contract-audit.json` reports **9 checks passed,
10 failed, 2 blocked**. All 8,027 primary records pass the catalog JSON Schema,
but 153 references reveal records before their release time. Manifest, license,
identity/checkpoint oracle, replay, query, negative-input and validation-report
support shapes differ from the documented contract. The separate 26-record
control pack now passes its file checks. See each rule's measured examples; no application replay was run.

This audit leaves the catalog, stable IDs, media bundle and previous reports
unchanged. Repair release dependencies and support contracts before building a
complete importer/replay around this preview. Top-level shape checks do not
exhaustively validate nested semantics. The audit/control tools' 18 unit tests pass;
its corpus audit intentionally exits 1 for the observed data failures.

- Geography is 170/1,000: the remaining 830 records require verified geographic
  inputs. The current points reuse four settlement anchors; no approved area
  polygons or historical flood boundary are supplied.
- The control pack is under `tests/fixtures/bhotekoshi-2016-exercise-v1/control/`.
  Its two incidents and ten people are outside the primary counts; runtime
  isolation/reset still requires a compatible importer.
- Query and invalid-input files currently contain planning placeholders. They
  are not a finished evaluation suite; expected query evidence is unpopulated.
- Checkpoint oracle rows are specified targets, not executed observations.
- No importer, application replay, reset, alert, identity-resolution, agent trace,
  or UI asset-loading behavior was verified for this corpus. In particular,
  **reset is not confirmed working for this dataset**.
- The optional video pack is deferred. Media are dummy assets, not photographs
  or evidence of the historical event.

To rerun data checks, use Python 3.10+ with Pillow and jsonschema available in a
separate tooling environment (no application dependency changes are required):

```sh
python3 tools/test_data/schema_check.py
python3 tools/test_data/validate_dataset.py
# Strict supplementary audit (currently exits 1 for genuine corpus failures):
python3 tools/test_data/audit_contracts.py
python3 -m unittest discover -s tools/test_data -p test_contract_audit.py
```

Run these after restoring media. The validator writes measured reports and hero
fixtures; exit zero means implemented checks passed, even if geography remains
blocked. Read the `blocked` array. Do not present a zero exit code as full corpus
completion. Generation commands are documented in `tools/test_data/README.md`.
