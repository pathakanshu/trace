# Team status board

Shared state for everyone pushing to this repo tonight. Read it after every
`git pull`, update it in the same commit as your work. Keep entries short.

Rules:
- Only edit your own section, plus append lines to "Log" (newest last). This
  keeps merge conflicts to one-line appends.
- Before starting work, list the files you will edit under "Working on".
  If someone else already lists a file, message them first.
- Merge to `main` only after `jac test` and `jac build --check_only` pass.
  `git pull --rebase origin main` before every push. No force-pushes.

## Deadlines (organizers on Discord)

- 9:00 AM Sun: first Devpost draft, required for judging consideration.
- 11:00 AM EDT Sun: final Devpost submission (the Devpost page shows 11:00;
  Discord said noon; asked organizers to confirm). Judging 12:30 to 2:00.

## Current main

- Demo loop works on JacHammer (LATEST TRACE): Reset, Simulate hospital
  report, one alert, both reports kept.
- Report investigation uses NVIDIA Nemotron with a passphrase and a request
  cap (`docs/INVESTIGATION.md`). The two seeded reports replay recorded runs
  after Reset.

## Miguel (investigation stages)

Done: stages 0 to 4 on main (Nemotron boundary, replayed runs, panel and Graph
nodes, five-case live eval, docs). JacHammer LATEST TRACE runs main; after a
pull use Stop then Run Preview.
Working on: stage 5 with the team: pitch, demo video, Devpost pass. Corpus
backend: `demo/corpus.jac`, `services/trace.jac` (list_incidents,
get_dashboard(incident_id), search_people, place counts), graph/ schema
(external_id, ReportedAt, HasSource), `features/graph/services.jac` (cap),
`tests/test_corpus.jac`, `demo/datasets/bhotekoshi-2016-exercise-v1/`.
Pending humans: one LIVE Investigate on JacHammer (passphrase typed in the
panel), demo video link, subtrack check, organizer answer on 11:00 vs noon.
Corpus (`codex/test-data` 814efd9): full 8,027-record corpus now imports into a
SEPARATE incident "Bhote Koshi exercise corpus (generated)" via `load_corpus()`;
the demo incident and its reset are unchanged. Imported: 1,150 people, 3,600
claims, 1,800 sources, 32 orgs, 170 locations, 200 media, 100 subscriptions.
Counted, not imported: 50 non-person subscriptions and the kinds without a
node type (vote, task, contribution, contributor, facility, infrastructure,
hazard, aid, investigation). 800 claims about non-person subjects are kept as
source history without an About edge. No duplicate candidates for the corpus
(pairwise over 1,150 people). Import 0.4 s and corpus dashboard 0.2 s in jac
test; on a persisted `jac start` server: import 1.4 s, corpus dashboard about
1 s (counts cached until the next import; the first count after a restart
takes about 3 s), demo dashboard and reset unchanged. The corpus is written with Jac's topology index off (it made the
import quadratic); corpus lookups use a field filter so they walk real edges.

## Anshu (map, integration)

Working on: corridor map + corpus report heat layer on `codex/anshu-map-scale`.
Reserved: `features/map/*`, `services/geo.jac`, new
`features/map/bhotekoshi-corridor.geojson`, README Map section, this section/log.
Task 1 implemented: current OSM river/settlements, faint district, corridor view
and attribution. Local browser endpoint/labels/pins work; 375px document has no
overflow (canvas 341px, caption 343px). No screenshot file saved. Task 2 consumes
Miguel's `place_counts` contract when it lands.
Miguel: planned endpoint `get_bhotekoshi_corridor`; after its commit lands,
replace the geo import in `main.jac` with exactly:
`import from services.geo { get_boundaries, get_bhotekoshi_corridor }`.
I will not edit main.jac or services/trace.jac. Latest user prompt authorizes
plain main push after rebase + both gates, deadline 09:40 EDT.

App handoff: all four overnight tasks complete; **draft PR #4** is ready:
https://github.com/pathakanshu/trace/pull/4 (`codex/anshu-night`). Audit/smoke work
already landed on main. Remaining feature commits: 600bafd People → Map,
ed3cb0b phone wrapping, 0e697ee report-location provenance regression.
Gabriel: People callback is optional; unmapped reports get no link. No graph,
endpoint, investigation, seed, dependency, live-model or hosted-deployment changes.

App validation on main 70c03c2: **57 Jac tests, 52-file compiler gate**, production
client build, local keyboard/mouse/repeated focus/search, 375px layout, publish /
retry (1 then 0 alerts), reset and persisted restart pass. Screenshot capture
failed; no screenshot claimed. Hosted/physical-phone rehearsal remains human work.
Own local server 8092 is stopped. Active developer checkout was never switched.
Jac language audit: GitHub 94.501% at 04:30 EDT; no Linguist padding/overrides.

Dataset branch: **codex/test-data**, latest candidate evidence fix **814efd9**.
Delivered: 8,027 records, 1,150 Person / 1,000 private identities, 1,800 reports,
3,600 claims; geography **170/1,000**. Hero is **748 reference-closed records**.
Published release has 200 dummy images + 200 thumbnails; restore/hash guide:
`demo/datasets/bhotekoshi-2016-exercise-v1/README.md` on codex/test-data.
Original sources/asset bytes are preserved. Only media creation metadata was
corrected from its original run receipt; licenses now have 200 contract entries.

**216 tooling tests pass** (201 core + 15 Pillow). Delivered strict audit:
**25 pass / 16 fail / 2 blocked**; media **11 / 0 / 1**. Clean remote clone at
948c5e4 reproduced the then-current 174 tests and both audits exactly, restored
400 files, left tracked files clean and created no .jac runtime store.

Candidate generator fixes pass temporary-output tests for all seven checkpoint
cohorts, ten rumor-opposition cases, exact raw envelopes/excerpts/locators,
non-author unique votes, two hero followers and coherent task evidence/times.
Candidate initial reports now supply contextual differences for all 20 same-name/age
negative pairs and 30 attributed accessibility/language support requests. No
diagnoses, resolver outcomes or unique identity keys are supplied.
Full temporary generation passes the combined checks and exports a
50-identity/62-Person candidate hero including both followers after repairing a shared-source boundary.
Candidate workflow substitution removes all 153 forward references. Main generation refuses nonempty
catalog/raw directories. These are **not fixes to the distributed source/workflow
snapshots**. No importer/replay/reset, identity decision, alert or agent answer
was fabricated or run for this corpus.

Needs team decision before replacing published inputs: namespace/version and
immutable-source migration. Current release still has final-cohort drift, six
unopposed rumors, 153 forward references, invalid community snapshots, ambiguous
hard negatives, zero support-needs citations, legacy support/replay shapes and
missing geography. All 170 current points pass full district-30 boundary membership;
this does not approve terrain, uncertainty envelopes or historical borders. Details and
integration sequence: `tests/fixtures/bhotekoshi-2016-exercise-v1/REPAIR_PLAN.md`
on codex/test-data. Keep all private expectations out of app/model inputs.
Branch-only handoff; Miguel integrates. No main merge or JacHammer deployment.

## Gabriel (people)

Working on: (fill in)

## Aidana (media)

Working on: (fill in)

## Open questions

- Is a recorded (replayed) model run acceptable to show judges alongside one
  live call? Ask in #ask-an-organizer.

## Log

- 03:40 main 2cf7cbe: Nemotron report check replaces the old provider.
- 03:55 main b71547e: map shows sourced current status (Anshu).
- 04:05 main 0233fca: seeded reports replay recorded Nemotron runs on Reset.
- 04:10 main 0b23355: README demo story and model config, eval table (live cases pending), deploy checklist.
- 04:25 JacHammer LATEST TRACE pulled main and restarted: Reset shows two
  REPLAYED runs in People (provider-reported tokens) and two Investigation
  records in Graph. After a pull, use Stop then Run Preview; hot reload alone
  left stale imports. Live eval waits on the key and passphrase in the
  coordinator's shell.
- 04:33 main 3a6e013: prompt v4 sends label definitions (byLLM dropped enum-field sem), DIRECT-with-source goes to review, 45 s call limit, seeded runs re-recorded (police now NEEDS_REVIEW), five-case eval in docs/INVESTIGATION.md. Redeploy JacHammer: fixtures and prompt changed.

- 04:39 codex/anshu-night 7f6a866: Jac share 94.501%; offline full demo regression, two resets and replay citation/provenance checks. 56 tests and 52-file compiler gate pass. Next: minimal People report-to-Map callback (Gabriel), then 375px checks.
- 05:05 main edee489: Anshu's offline demo regression test and language audit (Jac 94.5%) landed.
- 05:05 JacHammer re-pulled and restarted after stage 4: REPLAYED runs show the v4 recordings. Stage 5 drafts (pitch, video script, morning checklist) are with Miguel; Devpost story updated.
- 05:10 For Anshu's agent: Miguel's side is idle until about 8:00. You may land your own branch on main yourself: rebase onto origin/main, both gates pass, plain push (no force). Keep the file boundaries in your prompt.

- 04:49 codex/anshu-night 600bafd/ed3cb0b: People report-to-Map selection and 375px Organizations wrapping; 56 tests, 52-file gate, local keyboard/mouse/mobile/publish/retry/reset checks pass. All four overnight tasks ready; branch only.

- 04:53 codex/anshu-night 0e697ee: extra report-location provenance regression; 57 tests, 52-file gate and production web bundle pass. Draft PR #4 includes the full handoff.

- 05:00 codex/anshu-night 4375ad3: cold-started bundled client; both replay views work, hospital claim ID and one alert survive process restart, repeat watch adds zero, reset restores Missing. PR #4 ready.

- 05:15 codex/test-data 23f81dd: 40 cited private questions and 26 control records published; 25 tooling tests pass. Audit still reports corpus failures. Investigating final-cohort drift before any source rewrite.

- 05:34 codex/test-data fb64b72: 40 concrete negatives, 40 cited queries, 26 controls; 45 distinct offline tooling tests pass. Audit 13/10/2 and final-cohort/rumor defects documented. Published corpus bytes preserved; raw-envelope/asset-unpacker audit next.

- 05:41 codex/test-data 3866853/4039c8d: source envelope mismatch documented; real 400-file asset restore rehearsed twice. 60 tooling tests pass across two environments; hero reference-closure fix next.

- 05:51 codex/test-data 80b89c4/17dfdc3: fixed hero closure (658 records), added community checks and private REPAIR_PLAN. 74 tooling tests pass; strict audit 15/14/2 exposes unresolved corpus defects. Primary records/media unchanged.

- 06:09 codex/anshu-night ae827d4 / codex/test-data 6704431: private identities now contract-shaped, 20 ambiguous hard negatives and two cyclic review joins exposed. 104 tooling tests pass; strict audit 18/15/2. Fresh media audit next; no corpus load or original-byte changes.

- 06:20 codex/test-data 0fc9840/9b7748d: fresh 400-file media checks and all 40 derivative hashes pass; no asset bytes changed. 112 tooling tests pass; geography provenance audit next, no new coordinates.

- 06:34 codex/test-data b77e59d: clean-clone handoff rehearsed with fresh GitHub asset download; 119 tests and both published audits reproduced. No runtime store created. PR #4 now links STATUS and the private data repair guide.

- 06:40 codex/test-data ac7bdbe: public/private input boundary passes; 125 tooling tests. License migration paused on conflicting actual media creation/measurement timestamps; checking provenance before writing support metadata.

- 06:44 codex/test-data 6b19611: 129 tests pass; actual media audit exposes creation/measurement timestamp conflict in all 200 rows. Asset bytes untouched; license migration deferred. Fresh quota audit next.

- 06:47 codex/test-data f81c997: 137 tests; 24/25 catalog coverage dimensions pass, known location deficit fails. Source/correction provenance audit next; no primary input edits.

- 06:51 codex/test-data 741c2d4: source scope/DAG audit passes; 145 tests. Found media timestamp cause in build_media; reserve only metadata/hero/hash repair from original asset-run receipt, with source/asset bytes preserved.

- 06:58 codex/test-data 27a7285: 200 media creation times repaired from original receipt, 40 hero copies refreshed; raw sources/assets unchanged. 154 tests and media 11/0/1. Per-Media license inventory next, preserving existing terms and unknown encoder version.

- 07:02 codex/test-data 918d5b6: 200 per-Media usage records, original terms and unknown encoder version preserved; 162 tests. Preparing generator cohort fix only in temporary output; published source repair still needs version coordination.

- 07:06 codex/test-data 971066e: temporary candidate now meets every checkpoint and rumor constraint; 171 tests. Published reports untouched and regeneration guarded. Candidate exact raw-envelope generation next.

- 07:11 codex/test-data 948c5e4: 174 tests and both audits reproduced from clean remote clone + restored release assets. Candidate raw envelopes pass; delivered originals remain legacy. Candidate voter/follower fixes next.

- 07:17 codex/test-data 8efadde: 181 tests; candidate unique non-author votes and two hero followers pass. Published snapshots unchanged. Task/review and media-follow release coherence next; Anshu handoff section condensed with guide links.

- 07:23 codex/test-data 800e11f: 184 tests. Candidate tasks now match submissions and cited reviews; source/media release timing coherent, zero remaining forward references in substitution check. Full temporary generator rehearsal next; delivered snapshot unchanged.

- 07:32 codex/test-data c87eac2: 191 tests; full disposable generation + copied assets passes combined gates and a 50-identity/62-Person hero (802 candidate records). Fixed source-batch closure spill; no published source rewrite. Retaining Person subscriptions in hero export next.

- 07:41 codex/test-data aaf03ac: hero now retains all 62 subscriptions and their actors (748 total records); 193 tests. Candidate hero retains two distinct followers. Actual boundary membership audit next; geography remains incomplete.

- 07:46 codex/test-data e43e471: 170 existing points pass full district-30 polygon membership; 206 tests, strict audit 25/15/2. Boundary epoch/terrain/approved zones remain unverified. Candidate contextual evidence/support-needs coverage next.

- 07:52 codex/test-data 814efd9: 216 tests (201 core + 15 Pillow) pass. Candidate context/support requests pass full disposable corpus checks; delivered audit honestly 25/16/2, with zero support coverage newly exposed. Stopping at Anshu’s request; PR #4, asset release and private repair guide are the handoff. No merge/deploy/import.
- 05:25 main 7e694be: PR #4 squash-merged (People to Map, phone wrapping, demo regression; 57 tests, gate passed). Corpus import deferred until after judging (see Miguel section).

- 08:28 codex/anshu-map-scale: corridor linework, four labels, attribution, faint district and corridor fit ready; 59 Jac tests pass; final compiler gate required before push. Miguel: add `get_bhotekoshi_corridor` to existing services.geo import in main.jac. Task 2 follows place_counts backend.
- 08:50 main: corpus import as its own incident (load_corpus, list_incidents, get_dashboard(incident_id), search_people, place counts, capped graph). 66 tests pass; Maya demo unchanged. Also registers get_bhotekoshi_corridor in main.jac.
- 08:55 main: corpus counts cached between requests (server corpus dashboard 3-4 s down to about 1 s); verified on a restarted persisted server that the corpus survives and Reset plus hospital update still gives one alert.
