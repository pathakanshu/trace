# Map

The initial view frames the Bhote Koshi river corridor. Current OpenStreetMap
linework (four separate mapped ways) and Kodari, Tatopani, Bahrabise and Khadichaur
labels sit above a faint district background. The translucent river band is a
visual guide, **not a measured 2016 flood extent**. © OpenStreetMap contributors
(ODbL); attribution is available on the map. The bundled 18,016-byte GeoJSON is
an exact copy from `codex/test-data`; its provenance/archive references resolve
on that branch, not to a bundled corpus here. No other corpus inputs were copied.
Other rivers are OpenStreetMap `waterway=river` ways inside Nepal (ODbL, Overpass extract of 2026-09-27), simplified to about 400 m in `features/map/nepal-rivers.geojson`.

When the dashboard supplies `place_counts`, Map aggregates exact coordinates
without jitter and draws a heat layer weighted by report count. High-zoom circles
and the keyboard-accessible list open settlement totals and missing/safe/other
source assertions. The list shows at most the 20 busiest coordinates. The caption
separates located and unlocated reports; neither the glow nor the river band is
an uncertainty or flood boundary. Counts are reports, not unique people or media
locations. An empty count list preserves the Maya pins and evidence panel.
The additive count backend/importer is owned by Miguel. It is integrated from
814a07d; the map consumes its fields without changing the importer or schema.

The corridor loads independently of boundaries and evidence, with its own
five-second unavailable message and late recovery. HTML settlement labels need
no external glyph service. `get_bhotekoshi_corridor` is the server endpoint;
registered alongside `get_boundaries` in `main.jac` by Miguel.

People reports with mapped evidence offer **Show on map**. It opens Map,
selects the first linked place in snapshot order, and centers its pin. Repeating
the link centers it again; normal tab switches preserve the viewport and People
search. Reports without valid mapped evidence have no link. This navigation
follows the report's media location, not the person's current whereabouts.

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

Map checks (27 September, corridor/count consumer): 66 Jac tests and the
whole-program compiler gate pass, as does the production web client build. Nine real
Maya browser checks pass (hospital update/one alert, retained police evidence,
reload/reset, keyboard selection, pan/zoom/tab preservation, and failed/slow
boundaries). Eight additional browser component checks use explicitly mocked
count responses: exact-coordinate aggregation, 170 rows to four points,
high-zoom circle selection, source-status sums, top-20 cap, empty fallback and
corridor failure. Both suites pass at 375px with no document overflow or page
errors. These count fixtures are not an importer or a corpus execution result.
Four further checks pass against the real persisted corpus: idempotent import,
1,356 located / 2,244 unlocated reports at 170 records / four coordinates,
correct settlement status totals, 375px rendering, and reset isolation. The test
uses the shared incident-selector UI and unchanged backend responses. Counts were
Tatopani 345, Kodari 339, Khadichaur 339 and Bahrabise 333. No corpus alerts were
created. Local screenshots on Anshu's host:
`/private/tmp/trace-corridor-mobile.png` and
`/private/tmp/trace-real-corpus-mobile.png`.
Hosted deployment and physical-phone rehearsal remain untested.

If a development preview retains a compiler overlay after a source correction,
stop it and rebuild before restarting. A stale generated
`.jac/client/.jac-build-error.json` may retain the old error; remove that marker
only after a successful build confirms the correction. Do not reset shared data.

```sh
jac test features/map/test_map.jac
jac build --check_only
jac build --client web
# Separate terminal, in an isolated checkout with its own .jac/data:
jac start --dev --port 8092 --api_port 8093 main.jac
# With Playwright already available to Node (no application dependency added):
TRACE_MAP_URL=http://localhost:8092 node features/map/verify_map.cjs
TRACE_MAP_URL=http://localhost:8092 node features/map/verify_density.cjs
# Imports/reuses the real corpus in this isolated preview:
TRACE_MAP_URL=http://localhost:8092 node features/map/verify_corpus_map.cjs
```

The browser check resets the preview's demo. It accepts localhost only.
Set `TRACE_BROWSER_EXECUTABLE` to an existing Chromium executable if needed;
`NODE_PATH` can point to existing Playwright packages. Set `TRACE_MAP_SCREENSHOT`
to capture the 375px result. Shared integration change: a defaulted
`LocationEvidenceView.person_id` filled from the claim's `About` edge in the
location loop; no changes to the investigation snapshot fields or seed are needed.
