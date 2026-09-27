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
- 12:00 PM Sun: final Devpost submission. Judging 12:30 to 2:00.

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

Working on: `codex/anshu-night`: publishing language audit and offline full-demo
regression, then People-to-Map selection and 375px Map/Organizations.
Files: `docs/STATUS.md`, `tests/test_demo_flow.jac`; possible `.gitattributes`
only for genuinely generated/vendor content after measurement. Later:
`features/map/`, `features/organizations/`, a minimal People report link and
`components/TraceDashboard*` for selection; README Map subsection only.
Done: map status colours, map tests, boundary fallback (on main, b71547e).
Language audit (GitHub languages API, 27 Sep 04:30 EDT): Jac 303,368 bytes
(94.501%), JavaScript 9,598 (2.990%), CSS 8,055 (2.509%); total 321,021.
Source: `gh api repos/pathakanshu/trace/languages`. GitHub caches default-branch
Linguist analysis; local tracked Jac at ab3fc56 totals 317,497 bytes, so this
API snapshot can lag main. No language overrides/exclusions needed or added.
Method: https://github.com/github-linguist/linguist/blob/main/docs/how-linguist-works.md
This measures language share, not organizer eligibility or authored-code credit.
Offline flow: focused test passes; it checks both recorded runs/citations,
source preservation, one alert, repeat safety, map/graph references and two
resets with socket connections blocked. Full suite/build gate pending push.
Coordination: main is `ab3fc56`; I will push this branch only for Miguel to
integrate. No edits to investigation files, seed, graph schema, endpoints or
dependency declarations; no live model calls or large-corpus import.
Human follow-up: `anshu-next.md` says 11:00 final/10:00 freeze; this board says
12:00 final/09:00 draft. Keep the earlier required draft deadline and confirm
organizer timing before submission; no deadline assumption is treated as verified.

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
