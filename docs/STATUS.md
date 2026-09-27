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

Working on: stage 4, live eval of five report cases (needs the key and
passphrase in the running shell), then the JacHammer deploy.
Files: `docs/INVESTIGATION.md`, `README.md` (top, model config, demo steps),
`docs/DEPLOY_CHECKLIST.md`.
Next: fill the PENDING eval rows, deploy with `docs/DEPLOY_CHECKLIST.md`.

## Anshu (map, integration)

Working on: (fill in)
Files: (fill in)
Done: map status colours, map tests, boundary fallback (on main, b71547e).
Suggested next: check the 40% Jac share the way GitHub counts languages;
an end-to-end demo smoke script in a new file; "Show on map" from People.

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
