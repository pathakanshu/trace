# Trace

**One incident. Every trace.**

Trace is a graph-native disaster intelligence platform that connects people, claims, sources, locations, and media into a single evolving incident graph. Sources make claims; Trace keeps every claim with its provenance instead of pretending there is one truth. Jac walkers traverse that graph as new information arrives.

All people, sources and media in this repo are fictional.

The planned larger corpus is specified in [Test data rules](docs/TEST_DATA_RULES.md):
1,000 fictional individuals, 200 controlled images, and the broader disaster
graph, using cited 2016 Bhote Koshi context. This is a specification only;
the data has not been generated. For a later generation task, use the
[generator prompt](docs/TEST_DATA_GENERATOR_PROMPT.md) with its linked contracts.

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

## 3. The demo

1. If upgrading an existing starter graph, use **Demo controls → Reset demo** once
   to load the new fictional institutions. Reset is now incident-scoped.
2. Open **Organizations → Load hospital example → Review report**. Check the
   institution, explicit person record, source reference, and original text.
3. **Publish demo report** adds the source claim, then runs WatchWalker. Inspect
   the new report in Organizations, People, Graph, and the notification panel.
   The earlier police claim remains. A strictly newer dated status is an update,
   while differing latest/undated claims are labeled for review.
4. Review and publish the same form again: the same claim ID is returned, with
   no duplicate claim or alert. Changing content under the same report reference
   is rejected; a correction uses a new reference.
5. Reload: the graph data survives. Open **Map** and select the bridge pin to see
   its linked police claim, source, reported time, and media record.
6. **Reset demo** restores the starting scenario. Other incidents and shared
   nodes are preserved. The scripted hospital button remains as a fallback.

The form is for fictional demo publishers; it does not authenticate institutions.
All entered times are UTC; blank reported time stays unknown. Ingestion time is
recorded separately. No external API or model is required for this workflow.

## 4. Tests

```bash
jac test tests/test_trace.jac tests/test_publishing.jac
jac build --check_only
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
Incident -HasOrganization-> Organization -Publishes-> Source
Incident -Involves-> Person <-About- Claim <-Asserts- Source
Incident -Contains-> Media -LocatedAt-> Location
                     Media -HasSignal-> VerificationSignal
                     Media -Depicts-> Person      Claim -SupportedBy-> Media
Person -HasSubscription-> Subscription -Receives-> Alert
```

## 6. Intentionally simplified

- Demo data is hardcoded. There is no scraping and no external APIs.
- Structured institutional publishing and map evidence inspection work. Comments, voting, anonymous posting, uploads, and human identity confirmation remain assigned follow-up work.
- The map uses MapLibre GL with only the district/province borders from `geometry.topo.json` (no street tiles, so no token and no internet needed). Constituencies are in the file but not drawn yet.
- Verification signals come from demo fields on `Media` (`exif_gps_present`, `content_hash`, `community_location`).
- Name matching in ResolveWalker is a simple rule, not AI.
- No auth. Alerts are shown in the UI, not sent anywhere. Publishing is demo-only.
- Retry deduplication is tested sequentially in one local runtime. This is not a distributed exactly-once delivery system.
- The supplied JacHammer preview redirects to sign-in in a fresh browser session; a public deployment still needs verification.

## 7. Where to add things

- **Live ingestion / AI normalization**: build `IngestWalker(...)` calls from scraped records (`walkers/ingest.jac`).
- **Real EXIF / perceptual hashing / C2PA**: new `add_signal(...)` calls in `walkers/evidence.jac` (use Python libraries through Jac imports).
- **AI identity resolution**: replace `score_pair` in `walkers/resolve.jac`. Keep the output a *candidate*.
- **Notifications**: after the `Alert` is created in `walkers/watch.jac`.
- **Interactive map / graph viz**: `features/map/` / `features/graph/`.
- **New endpoint**: put the feature action in `features/<tab>/services.jac`; coordinate its registration in `main.jac` and any snapshot additions with Anshu.

Ground rules: every claim keeps its source, every signal keeps its explanation, conflicting claims stay visible, and AI or community output is evidence, not truth.

## 8. Publishing integration contract

See [docs/PUBLISHING.md](docs/PUBLISHING.md) for the additive schema fields,
endpoint arguments, ownership notes, and verification evidence for this slice.
