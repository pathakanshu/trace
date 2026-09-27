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
