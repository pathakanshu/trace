# Prompt for the later data-generation task

This prompt is intended for a **separate, subsequently authorized generation
task**. The current task created rules only. Give the next agent this file plus
the three linked specification files; do not paste only the count table.

---

You are preparing Trace's fictional disaster-response test corpus. Read these
repository files in order:

1. `AGENTS.md` and `docs/TEAM.md` for product boundaries and team ownership.
2. `docs/TEST_DATA_RULES.md` for the historical scenario, quotas, semantics,
   presentation, assets, evaluation, and current implementation gaps.
3. `demo/spec/quotas.json` for exact counts.
4. `demo/spec/record-contract.md` and `demo/spec/trace-record.schema.json` for
   exact file formats and fields.

The working historical setting is the **5 July 2016 Bhote Koshi flood in
Sindhupalchok**. Check the user's latest instructions for a different year before
generation. Preserve a clear separation between cited historical context and
the counterfactual response exercise. The 1,000 people, institutions, reports,
media, and operational events are fictional, not historical missing-person or
casualty statistics. Do not fabricate real agency statements or real victim
identities. Cite primary historical and geographic sources and preserve what
was known at each publication date.

Create the dataset files and actual media assets only. Do not change feature
implementations, install a new database, replace shared graph types, migrate
runtime storage, or load a production/shared incident. An importer and missing
features are separate engineering work. Report unsupported features explicitly.

Work in these stages:

**A. Validate the contract before writing records.** Read all four specification
files, inspect the relevant existing Jac graph/walkers/adapters, and produce a
brief capability report. Check quotas for contradictions. Resolve an ambiguity
in the contract explicitly rather than inventing a silent field or dropping a
required kind. Keep the primary corpus, optional video pack, and isolation pack
separate. Choose the hero records as a subset, not a second generated dataset.

**B. Ground geography and history.** Verify the cited historical sources.
Prepare the reference ledger and sourced geographic anchor/river inputs with
license/provenance, coordinate system, dates, and precision. The administrative
TopoJSON alone is insufficient for river, roads, settlement suitability, or
flood extent. Do not invent precise coordinates from place names. If a needed
coordinate/geometry cannot be verified, stop dependent placement and report
what is missing; continue independent work. Do not manufacture a flood-depth
simulation. An arbitrary exercise clock is not the actual flood-onset time.

**C. Allocate a deterministic generation plan.** Reserve all IDs, hidden
identity groups, image families, source cardinalities, statuses, map clusters,
language coverage, source dependence, and 12 narrative scenarios before prose
generation. Store evaluator-only labels only under the test/oracle directory.
Use seed 20160705 for deterministic sampling, while preserving actual generated
text/assets so reruns can reproduce the same corpus. Confirm that the chosen
hero subset includes all required stories and the full dependency closure.

**D. Generate text records in small, validated batches.** Use JSONL shards of
at most 100 records. Start with incidents, actors, locations, and typed subjects;
then sources, claims, media references, and community/research inputs. Use the
schema's exact fields and null conventions. Preserve original report text and
attributed claims. Create realistic independent reports, relays, corrections,
unknown times, same-name different-person cases, and conflicting evidence.
Do not pad with random relationships, repeated boilerplate, or uniform names.
Use short varied institutional bulletins and community language. Clearly mark
machine translations; do not claim human review that did not happen.

**E. Create real controlled assets.** Produce 120 original synthetic/staged
scenes, then the exact copy/transformation families totaling 200 uploads.
Use an available image-generation tool or controlled owned assets; do not
substitute nonexistent filenames or pretend prompts are images. Keep any
staged or generated provenance visible. Do not scrape victims or add real agency
logos. Transform assets using an authorized image-processing workflow, record
parameters, and compute SHA-256, sizes, dimensions, and metadata from bytes.
Exact copies must be byte-identical. Their captions/publications can differ.
Make thumbnails separately. Check the 160-unique-hash invariant. If asset
generation is unavailable, complete independent text work and report the asset
stage as blocked; do not label the dataset complete. Optional videos require
actual files and frame extraction; unsupported video analysis is not a pass.

**F. Author replay actions and held-out expectations.** Reserve later reports
for their scheduled actions so baseline loading cannot spoil the demo. Include
Maya's review/hospital/subscription flow, late old reports, equal-time/undated
disagreement, duplicates, correction references, optional tool failure, retries,
and isolated reset. Human review actions must carry reasons and visible evidence.
The oracle may know that two records are the same fictional individual; the
resolver and UI must not read it. Do not prefill candidates, identity approvals,
successful verification results, alerts, or agent execution logs. Expectations
are plans for evaluation, not proof of execution.

**G. Validate and package.** Use actual code to run structural and cross-record
checks in section 12 of the rules. Check counts, references, chronology,
geometry, source dependence, real file properties, duplicate groups, no oracle
leakage, and every required scenario. Build a contact sheet for human asset
review. Store real validation results with failed/blocked checks and evidence.
If the app cannot import a kind or execute a scenario yet, list it as deferred;
do not fake a passing demo. Runtime tests require a compatible importer and
explicitly isolated demo graph. Preserve unrelated incidents and teammates'
work. Never directly edit `.jac/data/*.db`.

Output paths are defined in the rules: text catalogs under
`demo/datasets/bhotekoshi-2016-exercise-v1/`, media under
`demo/assets/bhotekoshi-2016-exercise-v1/`, and private evaluation/replay files
under `tests/fixtures/bhotekoshi-2016-exercise-v1/`. Add an asset ignore rule
before writing binary files; package binaries separately with a computed
checksum. Do not auto-publish the corpus or contact anyone.

When finished, provide:

- Exact generated counts versus the quota file, separately for primary, hero,
  optional video, and isolation profiles.
- The manifest, actual asset-bundle location/checksum/size, schema validation
  output, semantic validation output, and unresolved limitations.
- A concise history/fiction explanation, a source/license ledger, and a
  walkthrough of the 12 stories and seven map checkpoints.
- A list of runtime features tested, not tested, and blocked. If an input or
  asset is missing, say the package is incomplete rather than claiming success.

A convincing demo comes from one understandable, cited change propagating
through all five tabs and the real Jac graph. Visual polish must expose evidence
and uncertainty; it must never manufacture verification.
