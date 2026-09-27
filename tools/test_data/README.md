# Exercise data tools

Work only in a dedicated test-data checkout. Python 3.10+ is recommended;
Pillow is needed for assets/semantic validation and jsonschema for schema checks.
These are tooling requirements, not application dependency changes.

The current generated snapshot is checked in. To consume it, follow
`demo/datasets/bhotekoshi-2016-exercise-v1/README.md`; do not regenerate assets
because the distributed manifest pins their exact bytes.

Generation order (scripts write within this checkout):

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
The current corpus audit has 9 pass / 10 fail / 2 blocked; failures are intentional
findings in the partial dataset, not successful runtime behavior.

## Isolated control pack

`python3 tools/test_data/generate_controls.py` creates only the 26 control records
and their two original source documents. It never regenerates primary records or
assets. IDs are reserved from 900001; names/reference text deliberately collide
across incident/publisher scopes. The generator preflights every destination,
refuses differing existing content or escaping paths, and leaves identical files
untouched. There is no runtime import or reset call.

Run all 18 tooling checks with
`python3 -m unittest discover -s tools/test_data -p 'test_*.py'`.
The tests include saved-source tampering, malformed control rows, exact schema
and counts, reference/release isolation, raw hash/excerpt checks, collision scopes,
idempotent generation and refusal to overwrite different files or escape root.
