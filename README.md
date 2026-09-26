# Trace

**One incident. Every trace.**

Trace is a graph-native disaster intelligence platform that connects people, claims, sources, locations, and media into a single evolving incident graph. Sources make claims; Trace keeps every claim with its provenance instead of pretending there is one truth. Jac walkers traverse that graph as new information arrives.

All people, sources and media in this repo are fictional.

## 1. Install

Use the Jac 0.34.x native binary to match this JacHammer scaffold (validation uses 0.34.1).
Check `jac --version` first; the 0.37 CLI has incompatible configuration/commands.
Jac 0.34 is distributed as a binary, not the `jaclang` package on PyPI. See the
[official installation guide](https://docs.jaseci.org/quick-guide/install/) for
versioned binary installation. Then, from the project folder:

```bash
jac install
```

## 2. Run

```bash
jac start --dev main.jac
```

Open the URL it prints (usually http://localhost:8000). In JacHammer the live preview is already running.

## 3. The demo (about 30 seconds)

1. The dashboard auto-seeds **Bhote Koshi Flood Demo** and opens Map. Switch to **People**: Maya Gurung is **MISSING** (claim by *Nepal Police Demo*).
2. See "Maya G." flagged as a **potential duplicate**. ResolveWalker never merges people.
3. Open **Demo controls** and click **Simulate hospital report**. IngestWalker adds *Central Hospital Demo*: **FOUND_SAFE**, then WatchWalker runs.
4. You should see:
   - both claims kept on Maya's timeline (the police claim is not overwritten)
   - a banner explaining that the reports say different things
   - an alert for Maya's subscriber, Asha
   - the same hospital report in **Organizations** and **Graph**, plus the shared activity feed
5. Click **Reset demo** to start again. **Check for updates** reruns WatchWalker; claims it has already seen are skipped.

## 4. Tests

```bash
jac test tests/test_trace.jac
```

## 5. Five tabs and team ownership

The dashboard switches between **Map, People, Media, Organizations, Graph** in
place. Tabs preserve their local search/selection state and share one graph
snapshot. Notifications and activity remain visible beside every tab.

Read [docs/TEAM.md](docs/TEAM.md) before starting parallel work. It defines the
component contract, backend ownership, merge workflow, product guardrails, and
manual acceptance checks.

| Owner | Folder | Main entry |
| --- | --- | --- |
| Aidana | `features/media/` | `MediaTab.jac` |
| Gabriel | `features/people/` | `PeopleTab.jac` |
| Miguel | `features/graph/` | `GraphTab.jac` |
| Anshu | `features/organizations/` | `OrganizationsTab.jac` |
| Anshu | `features/map/` | `MapTab.jac` |

Shared integration lives in `components/TraceDashboard*`, `components/shared/`,
`services/trace.jac`, `main.jac`, and `jac.toml`. The graph schema stays in `graph/`
and graph behavior stays in `walkers/`. Anshu coordinates shared integration;
Miguel coordinates graph schema changes. Feature folders also hold their own
helpers, adapters, and tests as those are added.

The graph:

```
Incident -Involves-> Person <-About- Claim <-Asserts- Source
Incident -Contains-> Media -LocatedAt-> Location
                     Media -HasSignal-> VerificationSignal
                     Media -Depicts-> Person      Claim -SupportedBy-> Media
Person -HasSubscription-> Subscription -Receives-> Alert
```

## 6. Intentionally simplified

- Demo data is hardcoded. There is no scraping and no external APIs.
- The tab split provides workspaces, not implemented comments, voting, anonymous posting, uploads, or institutional publishing. Organizations currently groups existing institutional reports by source; it does not yet have Organization nodes.
- The map uses MapLibre GL with only the district/province borders from `geometry.topo.json` (no street tiles, so no token and no internet needed). Constituencies are in the file but not drawn yet.
- Verification signals come from demo fields on `Media` (`exif_gps_present`, `content_hash`, `community_location`).
- Name matching in ResolveWalker is a simple rule, not AI.
- No auth. Alerts are shown in the UI, not sent anywhere.

## 7. Where to add things

- **Live ingestion / AI normalization**: build `IngestWalker(...)` calls from scraped records (`walkers/ingest.jac`).
- **Real EXIF / perceptual hashing / C2PA**: new `add_signal(...)` calls in `walkers/evidence.jac` (use Python libraries through Jac imports).
- **AI identity resolution**: replace `score_pair` in `walkers/resolve.jac`. Keep the output a *candidate*.
- **Notifications**: after the `Alert` is created in `walkers/watch.jac`.
- **Interactive map / graph viz**: `features/map/` / `features/graph/`.
- **New endpoint**: put the feature action in `features/<tab>/services.jac`; coordinate its registration in `main.jac` and any snapshot additions with Anshu.

Ground rules: every claim keeps its source, every signal keeps its explanation, conflicting claims stay visible, and AI or community output is evidence, not truth.
