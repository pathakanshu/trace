# JacHammer deploy checklist

For the LATEST TRACE project on JacHammer, which tracks `origin/main`. Record the
answers in the team status log. Never push JacHammer's own commit that only
rewrites `[jachammer] project_id`.

## Before deploying

- [ ] Pull `origin/main` in JacHammer (History → Pull) and confirm the head commit.
- [ ] Jac version: leave "Default" (0.34.20 at last check; the preview ran on it).
- [ ] Project environment variables (project level, not global, so they reach a
      permanent deploy):
  - `NVIDIA_NIM_API_KEY`: the NVIDIA key (exact name; an older entry was `NVIDIA`).
  - `TRACE_LIVE_PASSPHRASE`: the team passphrase. Share it only with the team. It
    gates live model checks and, when set, also locks publishing, PFIF import and
    media changes for visitors (footer → **Unlock editing**).
  - `TRACE_MODEL_REQUEST_CAP`: `50` for the public deploy. The ledger is per
    deploy, so this bounds spending even if it resets with a new sandbox.
  - `LITELLM_LOCAL_MODEL_COST_MAP`: `True`.
- [ ] `[scale.admin] enabled = false` is still in `jac.toml` (no default admin login).

## Smoke steps (in this order)

1. Build log shows the dependency install and `litellm` 1.102.1 (look for
   `deps_installed` and "litellm CustomLogger registered"). Write down what it shows.
2. Open the app. Wait for the incident switcher (the corpus imports itself on a new
   store), then story bar → **Start over**.
3. People → community report: REPLAYED, NEEDS_REVIEW, RELAY to Nepal Police Demo,
   two citations, model id and the recorded run time. Nepal Police report: REPLAYED,
   NEEDS_REVIEW, RELAY with no named source.
4. Footer → **Unlock editing** with the passphrase (publishing is refused before
   that). Organizations → **Load hospital example → Review → Publish**: exactly one new alert,
   police MISSING claim still listed.
5. Organizations → publish the Flood Relief Demo relay from the README demo steps
   (reference `NGO-RELAY-001`).
6. People → that report → **Investigate** with an empty passphrase: UNAVAILABLE, no call.
7. Same report with the passphrase: LIVE, RELAY to Central Hospital Demo, comparison,
   NEEDS_REVIEW, usage line. This is the one hosted live call (2 requests).
8. **Investigate** again: CACHED, same run time, no call.
9. Graph: Investigation nodes with edges to the cited claims.
10. Redeploy (or restart the sandbox), then **Start over**: the two REPLAYED runs return.
11. Ledger: if JacHammer shows the sandbox files, read `requests` in
    `.trace-local/model-usage.json` before step 7, after step 7 (expect +2) and after
    step 10. Same count after the redeploy means `.trace-local/` survived; 0 or
    missing means the cap is per sandbox (expected). If the files are not visible,
    record "not checked".

## If something fails

- litellm missing: the app still boots and live checks say UNAVAILABLE. Demo the
  REPLAYED runs and say live checks run locally.
- Live call FAILED or times out (45 s limit; NVIDIA's API took over 20 s on 2 of 15
  calls during testing): the request stays counted; do not retry more than once. Fall back to the REPLAYED runs.
- Blank page or 500: roll back to the previous deploy in JacHammer and use local
  preview (`jac start --dev main.jac`) as the demo fallback.
