# Map — Anshu

`MapTab.jac` displays graph-backed locations and an evidence inspector.
`IncidentMap.jac` renders Nepal boundaries and accessible, selectable pins.
The first load frames known locations; tab switches preserve the viewport.

Selecting a pin (or the fallback place list) shows linked media and claims,
source names, report references, and reported times. It does not infer a live
person location. Seeded media and unverified reported locations are labeled.
Unknown/default 0,0, nonfinite, and invalid coordinates are omitted by the server.

Keep feature work here and boundary loading in `services/geo.jac`. See
[the publishing contract](../../docs/PUBLISHING.md) for the additive LocationView
fields. All tabs still accept the read-only snapshot and onRefresh callback.
