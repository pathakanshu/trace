# Team status board

**Code freeze: 11:45 EDT.** After that only fixes for a broken demo; Devpost closes at noon.

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

Done: deterministic person timeline on `codex/person-timeline`, **37e25a8**,
rebased on main **8489a32**. Ready for Miguel to cherry-pick/review; not merged.
New read-only `person_timeline(incident_id, person_id)` endpoint and shared People
panel work for both incidents, including the unindexed corpus. All sources stay
separate. Status changes compare consecutive claim types, never identity or truth.
Latest 50 entries, chronological; `total_entries` on each row is the uncapped
count (empty list = zero). Alerts/runs carry their cited claim's reported/ingested
clock plus their own recorded time; missing citations stay explicitly unknown.
Reset recreates graph IDs/ingestion times; the source-history content is repeatable.

Validation: **12 timeline tests; 80 total Jac tests passed**, whole-program gate
**61 files passed**, production web build passed. Five local browser checks passed:
initial police + replay, hospital retaining police/status change/one alert, 375px,
corpus/back, Reset refresh; zero page errors. Initial six unrelated mock-model test
failures were missing litellm in this clone. Jac native `install` reported success
with an empty venv; installing the existing `litellm==1.102.1` pin via uv into the
project site-packages made the full suite pass. No dependency files changed.
No live calls or stored results fabricated. Miguel's reserved files untouched.

Exact added `main.jac` line (the only main change):
`import from services.timeline { TimelineEntry, person_timeline }`
Exact mount in `features/people/Panels.jac`, already included (Gabriel lists no active work):
`{incidentId and <PersonTimeline incidentId={incidentId} personId={person.id} refreshToken={person} />}`
PeopleTab/CorpusPeople pass `incidentId={snapshot.incident_id}` to ClaimsPanel.
Cold-restart after integration. Working next: fresh-clone regression on latest main,
then Devpost screenshots outside the repo. No further feature reservations.

Done: corridor map + corpus report heat layer on `codex/anshu-map-scale`.
Reserved: `features/map/*`, `services/geo.jac`, new
`features/map/bhotekoshi-corridor.geojson`, README Map section, this section/log.
Task 1 landed on main: **34f3d9a / 48b597f**. Current OSM river/settlements,
faint district, corridor fit and ODbL attribution; not a measured flood extent.
Task 2 consumer **e6adde2** + integration **f2932f8** (rebased on ca017d7): exact-coordinate aggregation, weighted heat, clickable
high-zoom circles, keyboard status breakdown, top-20 list, empty-count fallback.
Miguel's backend/import registration landed in 814a07d during rebase.
Real persisted corpus integration passes: 1,356 located / 2,244 unlocated
reports, 170 records grouped at four coordinates; Tatopani 345, Kodari 339,
Khadichaur 339, Bahrabise 333. Import retry creates nothing; no corpus alerts.
The browser test now uses Miguel's real incident-selector UI (ca017d7) and
unchanged server responses. Switching back to Maya restores its cited pins.

Validation: **66 Jac tests**, **whole-program compiler gate**, production web bundle;
**9 Maya + 8 density fixture + 4 real corpus browser checks**, zero page errors.
Hospital update creates one alert; source history/reload/reset remain correct.
375px caption/legend/list have no document overflow. Actual local Maya screenshot:
`/private/tmp/trace-corridor-mobile.png` and `/private/tmp/trace-real-corpus-mobile.png`
(Anshu's machine, not portable assets).
Own isolated server 8092 stopped after checks; active developer checkout untouched.
Hosted preview and physical phone not exercised. Maya reset preserves corpus counts.

Miguel has registered the endpoint in 814a07d with:
`import from services.geo { get_boundaries, get_bhotekoshi_corridor }`.
Keep the agreed `place_counts`, `located_reports`, `unlocated_reports` fields;
UI consumes them automatically. Pull main and cold-restart before integration
checks. I did not edit main.jac, services/trace.jac, graph, demo or other tabs.
Overnight PR #4 was merged (7e694be); its old draft handoff is superseded.

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


### Final fresh-clone regression — 10:16 EDT

**PASS on main 8489a3259a08351a64e1e0b6014b6fc4f685815e** (includes
59a219a reset/media fixes and 1942e34 Nepal rivers). New clone, initially absent
`.jac/data`, cold `jac start` on localhost:8096; real UI/API, no response stubs.
**17 rehearsal checks + 3 map checks + 3 restart checks passed; zero page errors.**
**68 Jac tests and the 58-file compiler gate passed.** Bundled client cold-started.
No live model calls, secrets, application edits, or developer-store access.

Earlier bugs, exact retests:

| Check / repro | Expected | Actual |
| --- | --- | --- |
| Reset → People → investigation Person record = Maya G. → Reset | Source selector remains usable; replay visible; Investigate enabled | PASS: one source option, REPLAYED visible, enabled without reload |
| Load exercise corpus → select corpus → Media, empty search | All 200 records available, asset limitations explicit | PASS: snapshot and UI both 200; metadata-only notice; upload/duplicate controls absent |
| Maya → Media after Reset | Honest missing-preview state, retained records | PASS: three explicit “Preview unavailable” panels; zero broken image elements |

Remaining rehearsal:

- PASS: Reset → both Maya selections show their two actual REPLAYED runs →
  Simulate hospital report → exactly one alert, police and hospital retained →
  Graph includes Alert and both Investigation records.
- PASS: choose uncached hospital report → Investigate with empty passphrase →
  UNAVAILABLE, no crash. Cached/replayed reports were not used for this check.
- PASS: first Load disables repeated clicks (incident selector is absent until
  the second incident exists). Second Load from a stale pre-import browser tab,
  while switching corpus → Maya in the first tab, creates `{}` and only two incidents.
- PASS: three Maya → corpus → Maya cycles preserve the one-alert state. Corpus
  Reset control is hidden; invoking reset_demo while viewing corpus preserves its
  counts. Switch back → Reset gives zero alerts, one police claim, two replays.
- PASS: all five tabs for both incidents at 375 × 812; document width stays 375.
- PASS: Nepal river layer renders (55 visible features at corridor zoom); Bhote
  Koshi amber rgba(242,175,72,1), other rivers blue rgba(40,140,212,1). Repeated
  zoom-out stops at 6.163 for the 1440px viewport (configured minimum 6 plus
  geographic bounds); another click cannot move it. World copies disabled.
  Corpus has four real heat groups above the river, visually checked; 1,356
  located / 2,244 unlocated reports. This is report density, not flood extent.
- PASS: stop server → cold restart with same store → both incident IDs persist.
  Full Maya AND corpus snapshots match before restart after excluding transient
  `_jac_*` serialization metadata. One hospital alert, source history, two
  replays, and corpus map remain; actual UI reopened both incidents.

Corpus tab switch milliseconds (click until visible plus two painted frames;
tabs stay mounted, these are not incident-fetch timings):

| Tab | Three runs | Median |
| --- | --- | --- |
| People | 63 / 67 / 67 | 67 |
| Organizations | 67 / 67 / 67 | 67 |
| Graph | 83 / 67 / 67 | 67 |
| Map | 66 / 66 / 66 | 66 |

First corpus selection during concurrent repeat import: **7.382 s**. Later
corpus selections: **1.378–2.890 s**; Maya: **94–113 ms**. Local machine, with
other validation running; not a production benchmark. Initial page: 286 ms
once cold server was ready. GitHub Linguist API for this main: **Jac 92.308%**
(372,857 bytes), JS 23,013, CSS 8,055. No vendored attributes needed/applied.
No new demo blocker found. Corpus assets remain metadata-only; local persistence
success does not change the separately documented JacHammer sandbox restart limit.

Evidence on Anshu's machine: `/private/tmp/trace-final-results.json`,
`trace-final-map.json`, `trace-final-restart.json`, `trace-final-tests.log`,
`trace-final-build.log` (same directory prefix); screenshots there too.
Report branch `codex/anshu-final-rehearsal` changes **only this STATUS file**.

Timeline handoff: `codex/person-timeline`, implementation **37e25a8**, documentation
**04594f3**, pushed; 12 focused / 80 total tests, 61-file gate, web build, five UI
checks passed. These timeline commits are not on the main revision rehearsed above.
Exact single new main import: `import from services.timeline { TimelineEntry, person_timeline }`.
The People detail mount and complete integration notes are included on that branch.
Completed: three real local Devpost screenshots, visually reviewed, saved outside
the repo in `/Users/anshu/Downloads/trace-devpost-20260927/`:
`01-people-investigation.png`, `02-graph.png`, `03-map-corpus-heat.png`.
`capture-manifest.json` records the tested revision and computed SHA-256 checksums.
People shows the actual REPLAYED run; Graph the hospital claim/alert; Map the
generated corpus. No image edits. Isolated servers stopped; finished early.

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
- 08:58 main: incident switcher (Maya story / corpus), Load exercise corpus in Demo controls, corpus totals strip; People status chips, 100 of N and server search; Organizations ranked by report_count; Graph per-kind totals and cap note. Demo-only controls and report checker hidden for the corpus. 66 tests, gate passed; browser-checked Maya reset + one hospital alert and the corpus views.

- 08:55 codex/anshu-map-scale: 34f3d9a/48b597f corridor on main; density consumer and map label fix ready. 9 real Maya + 8 mocked-count browser checks pass, 375px screenshot `/private/tmp/trace-corridor-mobile.png`. Backend fields/import registration remain Miguel-owned; final rebase/test/compiler gates precede push.

- 09:00 codex/anshu-map-scale 3088d5d + integration follow-up: rebased on Miguel 814a07d. Real persisted corpus → map pass (1356 located, 2244 unlocated, 170 records, four settlement points); 9 Maya + 8 fixture + 4 real corpus browser checks, no page errors, 375px screenshots above. main.jac registration already wired by Miguel. Shared incident-selector UI/hosted deployment remain his side; final rebase + 66-test / compiler gates before main push.

- 09:03 codex/anshu-map-scale e6adde2/f2932f8: integrated ca017d7; real incident-selector → corpus map → Maya checks pass with no response interception. All changes confined to map, geo and allowed docs. Existing endpoint registration is complete. Pull main and Stop / Run Preview on JacHammer; hosted rehearsal remains untested here. Final rebase and both required gates precede this push.

- 09:22 main: corpus heat was drawn under the river band, so the three riverside settlements barely showed. Heat now draws above it with a larger radius and intensity at corridor zoom; four hot spots visible locally. 66 tests, gate passed. JacHammer sandbox restart loses the corpus: click Load exercise corpus again after each Stop / Run Preview.
- 09:26 JacHammer go/no-go: GO on 5528766. Fresh preview: Load exercise corpus about 25 s; corpus Map heat at four settlements, People chips + 100 of 1,150, Organizations 32 ranked, Graph 7,053 records (401 shown). Maya story: Reset shows both REPLAYED runs, hospital report gives exactly one alert. Note: the corpus has its own generated "Maya Gurung"; in the pitch, show corpus scale from the totals, heat map and Organizations, not by opening Maya there.
- 09:51 main 59a219a: fixes from Anshu judge rehearsal. P1 investigation panel revalidates stored person/report ids against the snapshot, so Reset no longer empties the selectors (browser: select Maya G., Reset, REPLAYED + Investigate still shown). P2 corpus Media tab lists the 200 generated media records, read-only, uploads/duplicate check/edits hidden with a note. P3 seeded Maya media show "Preview unavailable: file not bundled" instead of broken images. 68 tests, gate passed. Map rivers/zoom limits in progress on miguel/map-rivers.
- 10:03 main 1942e34: map shows every OSM river in Nepal (waterway=river, simplified, 336 KB) with the Bhote Koshi in the warning colour; zoom capped 6 to 14, maxBounds around Nepal, no world copies; report heat stays above the corridor whatever loads first. JacHammer checked: Reset then hospital gives 1 alert; select Maya G., Reset, panel falls back with REPLAYED and Investigate enabled. Note: JacHammer restart empties the store, reload the corpus before presenting.

- 10:08 EDT Anshu: timeline ready on `codex/person-timeline` (37e25a8); 12 focused / 80 total Jac tests, compiler, web build and five UI checks pass. Exact import/mount above. Starting latest-main fresh-clone regression; no main push.
- 10:16 EDT Anshu: final fresh-clone main 8489a32 rehearsal PASS: 17 scenario, three map and three restart checks; all three earlier bugs retested fixed; 68 Jac tests/gate pass. Timings, 92.308% Jac and repro steps in Anshu section. Report only on codex/anshu-final-rehearsal; no main push.
- 10:58 main fd27d5f: PFIF 1.2-1.4 import in Organizations (features/organizations/pfif.jac + PfifImport.jac; endpoint import_pfif registered in main.jac). Notes become cited claims via IngestWalker, note_record_id is the reference (idempotent), unknown statuses skipped and listed, DOCTYPE/ENTITY refused. 4 new tests, 84 total; gate passed after removing a stale local agent worktree.
- 11:14 main 2d78f7e: Gabriel graph viewer (PR #7) merged; 84 tests + gate pass on main. Freeze moved to 11:45. codex/gabriel UI branch (story bar, theme toggle, alert banner, duplicate-incident fix) not merged yet: open a PR before 11:35 so it can be checked on JacHammer.
- 11:10 EDT Gabriel: demo UI on `codex/gabriel` 16952e8, JacHammer default 0.34.20 preview. Guided 4-step story bar, in-map legend, light/dark toggle, alert banner, Sources tab rename. Browser-checked on JacHammer: all four steps (step 2 opens the match review, step 3 gives exactly 1 alert and a banner keeping the police MISSING report, step 4 preselects the REPLAYED Maya G. relay check), Start over resets and repeats with 1 alert, light theme recolours the map, 375px has no overflow. Fixed: 11 duplicate "Maya story" buttons on a fresh store (startup requests now sequential; list shows one demo). Jac tests and verify_*.cjs scripts not run locally (no 0.34 binary here). JacHammer restart empties the store: reload the corpus before presenting.
- 11:29 main bd69ba7: codex/gabriel UI squashed onto main (8c021c8, authored by Gabriel) plus build-gate type fixes (bd69ba7). 84 tests + gate pass. JacHammer fresh preview checked: story bar steps, hospital step gives alert banner + 1 notification with police report kept, Graph diagram renders, PFIF panel under Sources, Start over resets, corpus loads with heat. Tagged demo-good-1135. Freeze 11:45.
