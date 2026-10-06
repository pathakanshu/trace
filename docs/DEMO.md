# Demo and checks

**Guided story bar.** In the Maya story, a bar under the header walks through four
steps: reported missing, same person?, hospital says safe, where did it come from?
Each step switches to the right tab and shows a large caption; its button runs the
real action (open the reports, open the match review, publish the prepared hospital
report, scroll to the source check). The hospital step shows a large banner built
from the stored alert, with the police report still listed beside it. **Start over**
resets the Maya story for everyone using the site; it is the only reset control. The
app opens in light mode, and the sun/moon button switches light and dark themes (remembered in
this browser; projectors usually read better in light). The map legend sits inside
the map; caveats are behind the (i) buttons and "How to read this map".

The detailed story, in order:

1. **Start over** (story bar) loads the fixtures and re-creates two recorded runs.
2. **People**: select the community report ("According to Nepal Police Demo...").
   It shows REPLAYED, NEEDS_REVIEW, labeled RELAY; Jac retrieved the police report it
   names and cites both excerpts. The police report itself is labeled RELAY with no
   named source (the officer recorded what the family said), so it also goes to a
   person rather than being accepted as first-hand. No model call.
3. **Sources**: **Load hospital example → Review report → Publish report**.
   One new alert for Asha Gurung's subscription; the police MISSING claim stays.
4. **Sources**: publish a Flood Relief Demo report for Maya Gurung whose text
   relays the hospital, for example: "According to Central Hospital Demo, Maya
   Gurung, 24, was admitted in stable condition this morning. Our team has not seen
   her." (a new reference, e.g. `NGO-RELAY-001`). No new alert: the status is unchanged.
5. **People**: select that report, type the passphrase, **Investigate**. Result is
   LIVE: attribution, Jac's retrieval of the hospital report, one comparison, both
   excerpts cited, usage and the ledger-backed cap. Investigating again shows CACHED.
6. **Graph**: the Investigation nodes link to the claims they cite.

Publishing the same form again creates no additional claim or alert. Reset restores
the scenario; unrelated incidents and shared nodes survive. Story step 3,
**Publish the hospital report**, is the scripted shortcut for step 3 here.

**Write lock.** On a server that sets `TRACE_LIVE_PASSPHRASE`, publishing a report,
PFIF import, and media upload, edit, delete, comment and claim all require that
passphrase (`services/access.jac`); the footer shows **Unlock editing**, which keeps
it for the browser tab. Reading, the story bar (including its prepared hospital
report and Start over) and identity review stay open to every visitor. With the
variable unset, as in local work and tests, nothing is locked.

There is no presenter tray. The exercise corpus is imported the first time the
incident list is requested on an empty store (about 3 s locally; a fresh JacHammer
sandbox took about 25 s when it was a manual step), so the incident switcher can
appear a little after the page does.

**When live is unavailable** (no passphrase, key, network or budget): step 5 shows
UNAVAILABLE or BUDGET_LIMIT with the server's message and sends nothing. The story
still works from the two REPLAYED runs in step 2, which are real recorded Nemotron
outputs, labeled as recorded with their original run time.

```sh
jac test tests features/people/test_identity_review.jac features/graph/test_graph.jac features/media/test_media.jac features/media/test_media_integration.jac
jac build --check_only
jac build --client web
```

The investigation suite uses a mock model (byLLM `MockLLM`) and a temporary ledger;
it makes no network or paid model calls. Browser acceptance steps are in the team contract; previously recorded
publishing/browser verification and its limits are in the publishing contract.
Local preview is the tested deployment fallback; public hosted access and a second
physical device still need verification.

## Code map

| Path | Responsibility |
| --- | --- |
| `main.jac` | Endpoint registration, CSS entry, and route |
| `components/TraceDashboard*`, `components/shared/` | Shared shell and presentation |
