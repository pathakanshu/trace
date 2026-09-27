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

### Fresh-clone judge rehearsal — 27 September, 09:32 EDT

Tested **bfdac73506fce5c4f957b029ce2815653ba88da0** from a new clone at
`/private/tmp/trace-judge-rehearsal-20260927-0920`. Confirmed `.jac/data` did
not exist before the first start. Ran documented `jac install`, then Jac 0.34.1
`jac start --port 8096 main.jac` cold, with NVIDIA_NIM_API_KEY and
TRACE_LIVE_PASSPHRASE absent. No live calls, secrets, or `.trace-local/` work.
Report branch: **codex/anshu-judge-rehearsal**. Only STATUS changed; no app
fixes or main push. Results below describe this tested revision, not untested
commits subsequently pulled for the report rebase.

**Bugs / exact reproductions**

1. **P1 — Reset strands the investigation selection.** Fresh Maya story →
   People → in "Investigate a report", select **Maya G.** → Demo controls →
   **Reset demo**. Expected: selector points at a current Person/Claim and its
   REPLAYED run remains available. Actual: Source report has **zero options**,
   Investigate is disabled, REPLAYED disappears, and the panel says "No check
   recorded yet for this report." The fresh snapshot still contains both
   replay records. **Reload fixes it.** Suspected cause (code inspection):
   InvestigationPanel retains selectedId/selectedClaim across the reset's new
   graph IDs. Miguel: clear/revalidate both on incident change; do not erase
   saved runs. Outside this task's permitted fix scope. Screenshot:
   `/private/tmp/trace-judge-investigation-reset.png`.
2. **P2 — Corpus Media tab contradicts its total.** Load exercise corpus →
   select it → Media, with search blank. Expected: imported media metadata or
   an explicit explanation that files/records are unavailable in this view.
   Actual: totals say **Media 200**, but the collection says **No matching
   media / Upload an image or change the search**. This is not a search filter
   the judge entered. Verified snapshot: `media` has 200 records, while
   `media_records` and `list_incident_media` both return zero. Screenshot:
   `/private/tmp/trace-judge-corpus-media-375.png`. No new media was invented
   or uploaded to conceal the gap.
3. **P2 — Seeded Maya previews are broken on a clean clone.** Select Maya →
   Media. Expected: usable preview or deliberate "preview unavailable" tile.
   Actual: all three cards show browser broken-image icons; requests for
   `/demo/flooded_bridge.jpg`, `/demo/reposted_flood_video.mp4`, and
   `/demo/flood_video_earliest.mp4` return **404**. The cards do correctly say
   they are seeded demonstration records, but the preview UI is broken.
   Screenshot: `/private/tmp/trace-judge-maya-media-375.png`.

**Pass/fail checklist**

- PASS: fresh empty-store cold start; first page ready in 326 ms after server
  readiness (this is page time, not dependency install/build time).
- PASS: Reset → People shows Maya Gurung and Maya G.; each investigation
  selector displays its actual REPLAYED run (two stored runs total).
- PASS: hospital action creates exactly **one alert**; both police MISSING and
  hospital FOUND_SAFE reports remain; Graph shows Alert and both Investigation
  records (40 nodes / 42 edges at that step).
- PASS: empty passphrase on the **uncached hospital report** returns
  **UNAVAILABLE**, with no crash or live request. Saved replay checks remain
  viewable without credentials by design.
- PASS: corpus loaded twice through real UI controls (second browser tab kept
  its pre-import Load button); second import returned `created: {}` and exactly
  two incidents remained. First Load disables itself; the incident selector is
  absent until a second incident exists. During the second tab's import, the
  first tab successfully switched corpus → Maya. No forced disabled clicks.
- PASS: three further Maya → corpus → Maya cycles preserve hospital reports
  and one alert; incident switch buttons disable while a switch is pending.
- PASS: while corpus is selected, Reset is hidden and the UI directs the user
  back to Maya. A deliberate local reset_demo endpoint stress call while viewing
  corpus leaves its totals/counts/zero alerts unchanged. Reset after switching
  back restores Maya's initial claim, zero alerts, and two replay records.
- PASS: stop and cold restart preserve both incident IDs, full Maya application
  state, and corpus totals/place counts/alerts. Comparison excludes regenerated
  `_jac_*` DTO metadata, not application IDs/content. Restarted UI shows the
  hospital already added, one alert, and the corpus reopens through the selector.
- PASS: all five tabs on **both incidents** at 375×812 have document width 375
  (10 checks); screenshots saved for each. This layout pass does not waive the
  Media content bugs above. No JavaScript page errors in the successful runs.
- FAIL: investigation replay/selection after choosing a person and then Reset
  (bug 1); corpus Media visibility (bug 2); Maya preview availability (bug 3).

**Corpus tab timing**, milliseconds from click to visible panel plus two paint
frames, local Chromium, 1280×900, already loaded incident; three rounds:

| Tab | Samples (ms) | Median (ms) |
| --- | --- | --- |
| People | 59, 67, 67 | 67 |
| Organizations | 68, 67, 67 | 67 |
| Graph | 83, 83, 83 | 83 |
| Map | 66, 66, 67 | 66 |

Incident loading is separate: first corpus switch during the repeat import
**6.362 s**; subsequent corpus switches **1.356–1.843 s**. Maya switches
**89–142 ms**. These are local measurements, not JacHammer latency claims.

**GitHub Linguist:** `gh api repos/pathakanshu/trace/languages`, with main
confirmed as bfdac73 at measurement: Jac **368,316 bytes / 92.2210%**,
JavaScript **23,013 / 5.7621%**, CSS **8,055 / 2.0169%** (399,384 total).
This is GitHub's language classification, not line/extension counting.
**Above 50%; no .gitattributes exclusions proposed or applied.**

Evidence on Anshu's host: `/private/tmp/trace-judge-results.json`,
`/private/tmp/trace-judge-investigations.json`,
`/private/tmp/trace-judge-restart.json`, and screenshots listed above. Initial
investigation-selector harness timeouts were corrected and rerun successfully;
they are not reported as application bugs. No test scripts/assets are pushed.

### Earlier map/data handoff

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
- 09:32 codex/anshu-judge-rehearsal (Anshu): fresh bfdac73 clone / empty store / cold restart rehearsal complete. Three reproducible findings in Anshu section: stale investigation selector after Reset, corpus Media 200→empty view, three 404 Maya previews. Core judge flow, repeat load, incident/reset isolation, persistence, empty-passphrase fallback and ten 375px layouts pass. Corpus tab medians 66–83 ms; GitHub Linguist Jac 92.221%. STATUS-only branch push; no main push, app edits or live calls.
