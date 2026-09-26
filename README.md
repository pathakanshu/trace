# Trace

**One incident. Every trace.**

Trace is a graph-native disaster intelligence platform that connects people, claims, sources, locations, and media into a single evolving incident graph. Sources make claims; Trace keeps every claim with its provenance instead of pretending there is one truth. Jac walkers traverse that graph as new information arrives.

All people, sources and media in this repo are fictional.

## 1. Install

You need Jac 0.34.x (`pip install jaclang`). Then, from the project folder:

```bash
jac install
```

## 2. Run

```bash
jac start --dev main.jac
```

Open the URL it prints (usually http://localhost:8000). In JacHammer the live preview is already running.

## 3. The demo (about 30 seconds)

1. The dashboard auto-seeds **Bhote Koshi Flood Demo**. Maya Gurung is **MISSING** (claim by *Nepal Police Demo*).
2. See "Maya G." flagged as a **potential duplicate**. ResolveWalker never merges people.
3. Click **Add hospital update**. IngestWalker adds *Central Hospital Demo*: **FOUND_SAFE**, then WatchWalker runs.
4. You should see:
   - both claims kept on Maya's timeline (the police claim is not overwritten)
   - a "Conflicting or updated status information detected" banner
   - an alert for Maya's subscriber, Asha
   - the new entries in the agent activity feed and the graph view
5. Click **Reset demo** to start again. **Run WatchWalker** is safe to repeat, because claims it has already seen are skipped.

## 4. Tests

```bash
jac test tests/test_trace.jac
```

## 5. Folder guide

| Folder | What lives there | Suggested owner |
|---|---|---|
| `graph/nodes.jac` | The 9 node types (+ ActivityEntry) | Person 1 |
| `graph/edges.jac` | The 10 relationships, with a diagram | Person 1 |
| `graph/activity.jac` | `now_iso()` + `log_activity()` for the activity feed | anyone |
| `walkers/ingest.jac` | IngestWalker: report -> Source/Claim/Person | Person 4 |
| `walkers/resolve.jac` | ResolveWalker: duplicate candidates | Person 1/4 |
| `walkers/evidence.jac` | EvidenceWalker: verification signals on media | Person 3 |
| `walkers/watch.jac` | WatchWalker: status changes -> alerts | Person 4 |
| `demo/seed.jac` | Deterministic demo data + reset | anyone |
| `services/trace.jac` | `def:pub` endpoints + view objects for the UI | Person 1 |
| `components/` | Dashboard page + panels (UI) | Person 2 |
| `tests/` | Small deterministic tests | anyone |

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
- The map is a schematic placeholder (plotted from lat/lng), not a real map.
- Verification signals come from demo fields on `Media` (`exif_gps_present`, `content_hash`, `community_location`).
- Name matching in ResolveWalker is a simple rule, not AI.
- No auth. Alerts are shown in the UI, not sent anywhere.

## 7. Where to add things

- **Live ingestion / AI normalization**: build `IngestWalker(...)` calls from scraped records (`walkers/ingest.jac`).
- **Real EXIF / perceptual hashing / C2PA**: new `add_signal(...)` calls in `walkers/evidence.jac` (use Python libraries through Jac imports).
- **AI identity resolution**: replace `score_pair` in `walkers/resolve.jac`. Keep the output a *candidate*.
- **Notifications**: after the `Alert` is created in `walkers/watch.jac`.
- **Interactive map / graph viz**: `MapPanel` / `GraphTreePanel` in `components/DashboardPanels.jac`.
- **New endpoint**: add a `def:pub` in `services/trace.jac` **and** list it in the import in `main.jac`.

Ground rules: every claim keeps its source, every signal keeps its explanation, conflicting claims stay visible, and AI or community output is evidence, not truth.
