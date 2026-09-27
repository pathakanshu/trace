# Separate control pack: inputs, not executed reset results

`records.jsonl` contains 26 fictional records: two incidents, ten people, two
organizations, two sources and ten claims. IDs use 900001 onward and are excluded
from every primary/hero quota. Each control source asserts five claims; its raw
JSON is under the dataset's `raw/reports/src-90000[12].json` paths required by the
catalog contract. Importers must follow each source's path rather than ingesting
all raw files as primary reports.

Both incidents deliberately use the name Maya Gurung (age 24) and the same report
reference under different incident/publisher scopes. These are separate records;
names and reference text must not cause a cross-incident merge or deduplication.
Location and observation time are unknown. There are no images or model results.

For a FUTURE isolated reset test, an importer must load the controls separately,
record their real runtime IDs/counts, load the primary T+12 baseline, and add the
specification's one deliberate shared-organization relationship. After resetting
the primary incident twice, compare the saved control IDs/counts and ensure the
shared node survives while claims remain scoped to their original incident.
The relationship is not pre-applied here. Corpus import/reset remains blocked;
these are test inputs and assertions to execute, not proof that reset succeeded.

Reproduce with `python3 tools/test_data/generate_controls.py`. Identical files
are preserved; differing existing files or escaping symlinks abort before writes.
Run `python3 -m unittest discover -s tools/test_data -p 'test_*.py'` for generator
and audit checks. `audit_contracts.py` also validates the saved control pack's
schema, counts, ID range, reference/time closure and raw source hashes/excerpts.
