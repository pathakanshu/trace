# Trace

**One incident. Every trace.**

Trace is a Jac disaster-reporting demo with one persistent incident graph and five
tabs: Map, People, Media, Organizations, and Graph. Sources make claims; new reports
retain earlier claims and their provenance. All people and reports are fictional.

## Start here

- [AGENTS.md](AGENTS.md): engineering and evidence rules.
- [Team contract](docs/TEAM.md): ownership, tab interfaces, and integration checks.
- [Publishing contract](docs/PUBLISHING.md): report validation, provenance, alerts, and reset.
- [Report investigation](docs/INVESTIGATION.md): the Nemotron report-attribution check, its setup, request cap, ledger, statuses, and tests.

## Install and run

Use the **Jac 0.34.1 native binary**, the tested version for this JacHammer scaffold.
Check `jac --version` first; do not substitute a different CLI version or the
`jaclang` PyPI package. See the [official installation guide](https://docs.jaseci.org/quick-guide/install/).
Commands below assume `jac` resolves to the working 0.34.1 binary.

```sh
jac --version
jac install
jac start --dev main.jac
```

Open the URL printed by the server. Run only one server against this checkout's
`.jac/data/` graph store. The core demo needs no model credentials. Live report checks need
the server settings in the investigation guide linked above.

## Current behavior and limits

- Organizations previews and publishes structured demo reports for an explicit person ID.
  Identical retries return the existing claim; changed content requires a new reference.
- WatchWalker creates in-app alerts from new source claims. Strictly newer dated
  reports are updates; differing latest or undated reports require review.
- People shows sourced timelines and deterministic name/age match candidates.
  Human reviewers can confirm/reject associations with attribution and history.
  Decisions preserve both records and do not merge timelines or change status.
- Map uses bundled Nepal boundaries and graph-backed evidence pins. Reported
  locations are unverified. No street tiles or map API key are needed.
- Media supports image uploads, real SHA-256 copy matching, editable upload details,
  comments, and attributed assertions through the shared snapshot. Seeded checks
  remain simulated. Real EXIF extraction, C2PA, and video analysis are not implemented.
- Graph inspects real node IDs, typed edges, identity reviews, and upload copy links
  from the shared snapshot. Derived/candidate links are labeled. Investigation runs
  and media contribution child nodes are not yet projected.
- People also offers a capped NVIDIA Nemotron check of one source report's
  attribution, with at most one follow-up source comparison. The model returns
  labels only; Jac chooses the next step. Results are advisory, stored separately
  from claims, and unavailable without the server passphrase and key. Offline tests
  use a mock model and do not establish semantic accuracy.
- No authentication, public publishing, continuous monitoring, or external alert
  delivery. CGX/PFIF import, free-text extraction, broader community workflows, and the
  large planned corpus are not implemented. Retry guarantees are tested sequentially.

### Map

Pins show the most urgent current report among people linked by a claim at that
media location: Missing, Needs review, Reported safe, then No current status.
Needs review includes conflicting reports, injury, or death. The evidence panel
cites current person reports separately from the retained media-linked reports.
A pin remains a reported media location; a status update does not relocate anyone.
The bridge changes from Missing to Reported safe after the hospital update while
retaining the police report. The seeded market has no linked person report and
therefore shows No current status. Identity candidates are not silently combined.

Pins and the keyboard-accessible place list work while district boundaries load.
A failed request or five-second delay displays a boundaries-unavailable message;
a late success restores boundaries without changing selection or viewport.
The map observes container resizing and keeps viewport/selection across tabs.

Map checks on Jac 0.34.1: all 48 repository tests passed (five focused map tests),
the whole-program type-check and web client build passed, and nine automated
Chromium browser checks passed without page errors. Browser checks covered the
hospital update/one alert, retained source evidence, reload/reset, pan/zoom and
selection across tabs, keyboard selection, 375px width without horizontal
overflow, status/citation edge cases, and failed/slow boundary recovery.
This was an isolated local preview; hosted deployment and a physical phone were
not exercised. The generated large corpus remains unimported.

```sh
jac test features/map/test_map.jac
jac build --check_only
jac build --client web
# Separate terminal, in an isolated checkout with its own .jac/data:
jac start --dev --port 8092 --api_port 8093 main.jac
# With Playwright already available to Node (no application dependency added):
TRACE_MAP_URL=http://localhost:8092 node features/map/verify_map.cjs
```

The browser check resets the preview's demo. It accepts localhost only.
Set `TRACE_BROWSER_EXECUTABLE` to an existing Chromium executable if needed;
`NODE_PATH` can point to existing Playwright packages. Set `TRACE_MAP_SCREENSHOT`
to capture the 375px result. Shared integration change: a defaulted
`LocationEvidenceView.person_id` filled from the claim's `About` edge in the
location loop; no changes to the investigation snapshot fields or seed are needed.

## Demo and checks

1. Use **Demo controls → Reset demo** to load the starting fixtures.
2. In **Organizations**, choose **Load hospital example → Review report → Publish demo report**.
3. Inspect the retained police claim, hospital report, and new notification in
   People, Organizations, and Graph. Inspect a map pin's linked source evidence.
4. Publish the same form again: no additional claim or alert. Reload to check persistence.
5. Reset to restore the scenario; unrelated incidents and shared nodes must survive.
   **Simulate hospital report** remains the scripted fallback.

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
| `features/<tab>/` | Tab UI, feature services, and focused tests |
| `graph/nodes.jac`, `graph/edges.jac`, `graph/activity.jac` | Persistent schema and activity helpers |
| `walkers/` | Ingestion, identity proposals/reviews, seeded and upload evidence, watching |
| `services/trace.jac`, `services/geo.jac` | Shared snapshot/actions and boundary data |
| `services/investigation.jac`, `integrations/nemotron.jac` | Report checks and the model boundary (typed labels, passphrase, ledger) |
| `demo/seed.jac`, `demo/reset.jac`, `tests/` | Executable fixtures, isolated reset, and tests |
| `styles/trace-tokens.css` | Trace theme tokens; imports generated `global.css` |

`.jac/` and `dist/` are generated/ignored. `.jac/data/` holds local graph data;
`.trace-local/` holds the persistent model request ledger. Neither is source code or a
cleanup target. `geometry.topo.json` is required map data.

## Future reference only

[Dataset rules](docs/plans/test-data/TEST_DATA_RULES.md) and their linked schemas,
quotas, and generation prompt specify a future corpus, not current fixtures or APIs.
Read these only for work on that corpus; current code,
tests, and the feature contracts above describe the implemented app.
