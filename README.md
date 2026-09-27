# Trace

**One incident. Every trace.**

Trace is a Jac disaster-reporting demo with one persistent incident graph and five
tabs: Map, People, Media, Organizations, and Graph. Sources make claims; new reports
retain earlier claims and their provenance. All people and reports are fictional.

## Start here

- [AGENTS.md](AGENTS.md): engineering and evidence rules.
- [Team contract](docs/TEAM.md): ownership, tab interfaces, and integration checks.
- [Publishing contract](docs/PUBLISHING.md): report validation, provenance, alerts, and reset.
- [Investigation setup](docs/INVESTIGATION_SETUP.md): optional Jev report-attribution checks, credentials, budget, and limitations.

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
`.jac/data/` graph store. The core demo needs no model credentials. For the optional
Jev integration, follow the separate setup guide linked above.

## Current behavior and limits

- Organizations previews and publishes structured demo reports for an explicit person ID.
  Identical retries return the existing claim; changed content requires a new reference.
- WatchWalker creates in-app alerts from new source claims. Strictly newer dated
  reports are updates; differing latest or undated reports require review.
- People shows sourced timelines and deterministic name/age match candidates.
  Human identity confirmation is not implemented; candidates do not merge records.
- Map uses bundled Nepal boundaries and graph-backed evidence pins. Reported
  locations are unverified. No street tiles or map API key are needed.
- Media shows **simulated checks from fixture fields**. Uploads, real EXIF/hash
  extraction, C2PA, and video analysis are not implemented.
- Graph shows a relationship tree from the shared snapshot. It is not yet a full
  visualization of every node/edge type, including investigation runs.
- People also offers an optional budgeted Jev check of one source report's
  attribution, with at most one follow-up source comparison. Results are advisory,
  stored separately from claims, and unavailable without explicit configuration.
  Offline tests do not establish provider access or semantic accuracy.
- No authentication, public publishing, continuous monitoring, or external alert
  delivery. CGX/PFIF import, free-text extraction, community contributions, and the
  large planned corpus are not implemented. Retry guarantees are tested sequentially.

## Demo and checks

1. Use **Demo controls → Reset demo** to load the starting fixtures.
2. In **Organizations**, choose **Load hospital example → Review report → Publish demo report**.
3. Inspect the retained police claim, hospital report, and new notification in
   People, Organizations, and Graph. Inspect a map pin's linked source evidence.
4. Publish the same form again: no additional claim or alert. Reload to check persistence.
5. Reset to restore the scenario; unrelated incidents and shared nodes must survive.
   **Simulate hospital report** remains the scripted fallback.

```sh
jac test tests/test_trace.jac tests/test_publishing.jac tests/test_investigation.jac
jac build --check_only
jac build --client web
```

The investigation suite uses injected responses and does not require paid model
calls. Browser acceptance steps are in the team contract; previously recorded
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
| `walkers/` | Ingestion, candidate resolution, simulated evidence, and watching |
| `services/trace.jac`, `services/geo.jac` | Shared snapshot/actions and boundary data |
| `services/investigation.jac`, `investigation/`, `integrations/jev.jac` | Report checks, questions, and provider adapter |
| `demo/seed.jac`, `demo/reset.jac`, `tests/` | Executable fixtures, isolated reset, and tests |
| `styles/trace-tokens.css` | Trace theme tokens; imports generated `global.css` |

`.jac/` and `dist/` are generated/ignored. `.jac/data/` holds local graph data;
`.trace-local/` holds persistent spending accounting. Neither is source code or a
cleanup target. `geometry.topo.json` is required map data.

## Future reference only

[Dataset rules](docs/plans/test-data/TEST_DATA_RULES.md) and their linked schemas,
quotas, and generation prompt specify a future corpus, not current fixtures or APIs.
The [broader investigation plan](docs/plans/JEV_INVESTIGATION_PLAN.md) describes
unimplemented extensions. Read these only for work on those plans; current code,
tests, and the feature contracts above describe the implemented app.
