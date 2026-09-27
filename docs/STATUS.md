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

Working on: stage 4 done locally (live eval, prompt v4, 45 s call limit,
re-recorded seeded runs). Pending: redeploy JacHammer and run the live step
from `docs/DEPLOY_CHECKLIST.md`.
Next: pitch, backup video, Devpost.

## Anshu (map, integration)

Working on: private identity-oracle normalization on `codex/test-data`:
`tools/test_data/generate_identities.py` + tests, `generate_catalog.py` hookup,
private `oracle/identities.jsonl`, strict audit and README/report updates.
Follow the existing closed contract, preserving private IDs/membership/ages;
derive primary/initial-place fields from allocation and existing initial claims.
Unknown geography stays null. No public source/record/asset changes or new
runtime identity decisions. Reader fix 948c09c is pushed; 81 tooling tests pass.

App handoff: all four overnight tasks complete; draft PR #4 ready:
https://github.com/pathakanshu/trace/pull/4 (branch `codex/anshu-night`).
Tasks 1/2 are already on main. Remaining feature commits: 600bafd People report
→ Map and ed3cb0b phone wrapping; 0e697ee adds report-location regression.
Gabriel: optional onShowOnMap callback in PeopleTab/Panels; no identity,
investigation or service changes. Unmapped reports get no link and cannot borrow
another report's media location. Repeated explicit navigation recenters the map.

App validation on main base 70c03c2: **57 tests**, **52-file compiler gate**,
and production client build pass. Offline smoke blocks socket connections and
compares both actual replay fixtures/citations, source history, graph links,
one alert, repeat safety and two resets. Browser keyboard/mouse, search retention,
map selection, 375x812 Map/Organizations long text, publish/retry (1 then 0 alerts)
and reset pass in isolated localhost. No console errors observed. Cold-start
bundled client works; hospital claim ID and single alert survive process restart;
Watch adds zero; reset restores Missing. Screenshot capture timed out; DOM and
interactions were verified. Hosted/physical-phone checks remain human follow-up.

Language audit: GitHub languages API reported Jac 303,368/321,021 bytes (94.501%),
JS 9,598 and CSS 8,055, Sep 27 04:30 EDT; cache may lag local Jac 317,497 bytes at
ab3fc56. No Linguist overrides/exclusions added. Not organizer eligibility proof.

Corpus published on origin/codex/test-data: e710475 control pack (26 records),
23f81dd 40 cited queries, a65364f checkpoint diagnostics, fb64b72 40 concrete
negative cases. **81 distinct tooling tests pass across schema/Pillow environments**
(78 + three separately run decoder checks). Primary 8,027 records and binary
bundle are unchanged. Strict audit: **15 pass / 14 fail / 2 blocked**.
New measured defects: T+72 fixture summary is 353 missing / 547 safe / 50 injured /
50 unresolved, target 650 / 250 / 50 / 50. The generator assigns 297 safe follow-ups
outside its intended cohort. Six death rumors lack required equal/unknown-time
opposition at release. Sources must not be silently rewritten; coordinate a
versioned repair. Also 153 future references, legacy support shapes and only
170/1,000 locations remain. Retry/injection cases are plans, not executed results.
All 1,800 raw hashes match, but 1,260 JSON reports fail the required envelope
shape. Bundle restore twice verified 400 files and preserved bytes/mtimes;
unpacker now rejects symlink escapes, corrupt inventory and overwrites.
Community defects: 360 self-votes, 120 duplicate voting pairs, 36 task target
mismatches, missing review citations and no hero Person with two followers.
Private integration/repair guide on codex/test-data:
`tests/fixtures/bhotekoshi-2016-exercise-v1/REPAIR_PLAN.md`. Coordinate immutable
source/version/quota decisions before any corpus-wide regeneration.
No corpus importer/replay/reset or model answers were fabricated or run.

Coordination: branch only, ready for Miguel to integrate. Keeping original
handoff boundary despite the board's offered self-integration option. No shared
graph, endpoint, investigation, seed, dependency or live model changes. No hosted
deployment. Use the board's 09:00 draft/11:00 final planning; timing/replay
eligibility still need team confirmation.

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
