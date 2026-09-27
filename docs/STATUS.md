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

Working on: all four tasks pushed; draft PR #4 is ready for integration.
Cold-start rehearsal complete. Corpus-only follow-up on codex/test-data:
23f81dd pushed 40 cited private queries; e710475 added 26 isolated control records.
25 tooling tests pass; measured audit 11 pass / 9 fail / 2 blocked. Primary
8,027 records and the media bundle remain unchanged; no corpus app import.
Working next: tools/test_data/audit_checkpoints.py + tests, audit_contracts.py,
measured contract-audit.json and dataset/tooling README. A read-only diagnostic
found 297 T+72 safe follow-ups assigned outside the intended safe cohort in
existing generate_catalog.py. Add a fixture-only checkpoint recomputation and
regression; do not silently rewrite published reports or claim app execution.
Then author contract-shaped private invalid-inputs.jsonl with generator/tests;
replace unreferenced bad-* placeholder IDs with required case-* IDs. No shared
app contracts or dependencies change. All data is on origin/codex/test-data.
Additional regression in features/map/test_map.jac passes: a new report does
not inherit another report's media location; invalid coordinates stay unmapped,
and only its explicit valid media link makes it navigable. Tasks 1/2 are on main. Gabriel: optional onShowOnMap callback in PeopleTab/Panels;
no matching, reviews, investigation or service changes.
Browser checks on isolated localhost (live credentials disabled): keyboard and
mouse link select/center bridge; repeated use recenters; search survives;
unmapped community/hospital reports have no link; hospital updates pin/status.
At 375x812 Map has 341px canvas and 375px document width. Organizations preview
with 191-character reference and 220-character URL path exposed overflow; fixed
wrapping in that feature. Preview, published report, expanded original text and
Map evidence now remain 375px wide. Publishing/retrying produced 1 then 0 alerts.
Reset removed the phone exercise report. No browser console errors observed.
Cold-started the bundled client with `jac start --port 8092`: both REPLAYED
views and the map link worked. After a hospital update and a second process
restart, the same claim ID and single alert persisted; Watch added zero alerts.
Reset restored Missing. This was the isolated worktree store only.
Screenshot capture timed out in the extension; DOM dimensions/interactions were
verified, but no screenshot artifact is claimed. Normal viewport restored.
Files changed: `tests/test_demo_flow.jac`, `components/TraceDashboard*`,
`features/map/MapTab.jac`, `features/map/IncidentMap.jac`, the PeopleTab/Panels
callback, OrganizationsTab/PublishReport wrapping, README Map and this board.
Feature commits: 600bafd (report-to-map), ed3cb0b (phone wrapping).
Final gates on base main 70c03c2: 57 tests pass (six focused map tests);
52-file compiler gate passes. Production web client build also passes.
Integration: https://github.com/pathakanshu/trace/pull/4 (draft, branch published).
Language audit (GitHub languages API, 27 Sep 04:30 EDT): Jac 303,368 bytes
(94.501%), JavaScript 9,598 (2.990%), CSS 8,055 (2.509%); total 321,021.
Source: `gh api repos/pathakanshu/trace/languages`. GitHub caches default-branch
Linguist analysis; local tracked Jac at ab3fc56 totals 317,497 bytes, so this
API snapshot can lag main. No language overrides/exclusions needed or added.
Method: https://github.com/github-linguist/linguist/blob/main/docs/how-linguist-works.md
This measures language share, not organizer eligibility or authored-code credit.
Offline flow: focused test passes; it checks both recorded runs/citations,
source preservation, one alert, repeat safety, map/graph references and two
resets with socket connections blocked. On main e444edd: 56 tests passed;
compiler gate passed (52 files). Recording verdicts are compared to their
actual fixture values, including Miguel's v4 police NEEDS_REVIEW result.
Coordination: branch only, ready for Miguel to integrate. The board offers
self-integration while Miguel is away; I am keeping the original handoff
branch-only boundary and leaving a reviewable branch. No edits to investigation files, seed, graph schema, endpoints or
dependency declarations; no live model calls or large-corpus import.
Human follow-up: hosted/physical-phone checks still need a human. Follow the
board's updated 09:00 draft/11:00 final planning; organizer timing and replay
eligibility remain questions for the team. No live model or hosted deployment
was performed here.

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
