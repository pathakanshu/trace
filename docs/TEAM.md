# Five tabs, one incident graph

All tabs switch inside the existing dashboard. They share `DashboardSnapshot`;
switching tabs does not navigate, reload the document, or fetch another copy of
the graph. Panels stay mounted to preserve search, selection, and future drafts.

## Ownership

| Owner | Feature folder | Existing backend responsibility |
| --- | --- | --- |
| Aidana | `features/media/` | `walkers/evidence.jac` |
| Gabriel | `features/people/` | `walkers/resolve.jac` |
| Miguel | `features/graph/` | `graph/nodes.jac`, `graph/edges.jac`; coordinate schema changes with producers |
| Anshu | `features/organizations/`, `features/map/` | `walkers/ingest.jac`, `services/geo.jac`; integration owner |

Anshu integrates shared changes to `main.jac`, `jac.toml`, `services/trace.jac`,
`walkers/watch.jac`, `demo/seed.jac`, `components/TraceDashboard*`,
`components/shared/`, shared styles, and the existing integration tests.
Ownership is a coordination agreement, not an access restriction.

## Tab contract

Keep these public entry components stable:

- `features/map/MapTab.jac`: `MapTab(snapshot, onRefresh, active)`
- `features/people/PeopleTab.jac`: `PeopleTab(snapshot, onRefresh)`
- `features/media/MediaTab.jac`: `MediaTab(snapshot, onRefresh)`
- `features/organizations/OrganizationsTab.jac`: `OrganizationsTab(snapshot, onRefresh)`
- `features/graph/GraphTab.jac`: `GraphTab(snapshot, onRefresh)`

`snapshot` is the existing `DashboardSnapshot` from `services/trace.jac`. Treat
it as read-only. `onRefresh` is an async callback: after a successful server
mutation, `await onRefresh()` so every tab and the activity sidebar see the new
graph. Refresh updates props without resetting tab-local state. Don't copy the
snapshot into local state or call `window.location.reload()`.

Put feature components, feature-only helpers, new server adapters (`services.jac`),
and focused tests (`test_*.jac`) inside your own feature folder. Explicit `sv import`
keeps server adapters on the server. Keep the persistent node/edge definitions
centralized in `graph/` and existing walker entry points in `walkers/`.
Do not import another tab's components or make another tab responsible for saving
your data. Shared presentation helpers live in `components/shared/Display.jac`.

When adding a server action, give Anshu the exact function import and Miguel the
fields/relationships it needs. Anshu registers the endpoint in `main.jac` and
coordinates additions to the snapshot. Add fields with defaults; don't rename
existing fields while someone else's branch still consumes them.

## Small next deliverables

| Tab | Present now | Next useful slice |
| --- | --- | --- |
| Map | Selectable graph-backed pins and linked claims/media; explicit unverified-location label | Optional cross-tab selection |
| People | Search, sourced timelines, explained duplicate candidates | Confirm/reject an identity candidate with an attributed association; retain both reports |
| Media | Search/type filter and clearly labeled simulated evidence cards | Upload one controlled image, compute real metadata/hashes, attach check results and limitations |
| Organizations | Review/publish structured demo reports, retain provenance, deduplicate retries, run WatchWalker | Integration with teammates’ slices |
| Graph | Person/source/claim/subscription relationship tree | Render actual node IDs and typed edges, including media; expose real walker activity |

Organizations now publishes structured demo reports through real
`Organization -> Source -> Claim` relationships. See `docs/PUBLISHING.md` for
the exact additive schema and endpoint contract before changing these fields.
The Graph tab is an inspector over the same graph, not a second database and not
a prerequisite for other features to write their claims.

## Product guardrails

- Editing a case means adding a correction/report with attribution. Never erase
  the earlier source's claim. Unknown details remain unknown.
- Comments, votes, and anonymous submissions are contributions/evidence, not
  authority to change a person's status or identity. Anonymous public display
  does not remove provenance or moderation needs.
- Keep human identity confirmation separate from media similarity. Matching
  names alone must not silently combine people.
- Do not build social posting, voting, anonymous publishing, video analysis,
  and a polished graph all at once. Complete one source-to-alert flow first.
- Only advertise checks actually run. Existing media results are simulated.
- Structured demo publishing now validates explicit person IDs, preserves
  provenance, rejects reused references with changed content, and deduplicates
  sequential retries. Reset is incident-scoped. General public publishing still
  requires authentication and stronger concurrency controls.

## Merge workflow

1. Everyone starts from the same integrated tab-split commit. If someone already
   has edits to the old panels, move those edits into their new feature folder
   before deleting/replacing anything on their branch.
2. Use one branch per owner, `codex/aidana`, `codex/gabriel`,
   `codex/miguel`, and `codex/anshu`. Separate folders reduce conflicts;
   sharing one mutable JacHammer workspace does not provide Git isolation.
3. Keep normal feature edits in the owned folder and assigned walker. Ask for
   a shared-interface change before depending on it; don't silently change it.
4. Integrate small working slices frequently. Anshu handles dependencies, endpoint
   registration, and snapshot assembly once, instead of four competing edits.
5. Run the feature checks and shared demo after integration. Preserve teammates'
   work; don't resolve conflicts by replacing an entire shared file.

## Manual acceptance check

- Click Map, People, Media, Organizations, Graph: exactly one panel is visible;
  the URL and document stay unchanged.
- Use Left/Right arrows and Home/End on the tab bar. Focus and selection move
  together, and inactive panels are hidden from keyboard navigation.
- Search People for Maya, switch away and back: the query/selection remain.
- Filter Media to Videos, switch away and back: the filter remains.
- Pan/zoom Map, switch away and back: the viewport remains and fills the panel.
- Simulate the hospital report from any tab: People, Organizations, Graph, and
  notifications reflect the same update without resetting the active tab.
- Reset the isolated demo and check all tabs again. Unrelated incidents and
  nodes referenced outside the demo must survive.
- At phone width, the tab strip scrolls and activity moves below the active panel.

This is a division of implementation ownership, not a claim that every feature
in the planning table already exists.

## Scaffold verification (2026-09-26)

- Jac 0.34.1: existing four demo tests passed. The test file is now
  `tests/test_trace.jac`; the previous dotted filename failed test discovery.
- Client bundle built successfully. MapLibre/TopoJSON are declared in `jac.toml`;
  `main.jac` explicitly includes the generated base CSS for Jac's asset copier.
- Browser checked: all five panels, one active panel, unchanged URL, retained
  People query and Media type filter, arrow/Home keyboard focus, and map rendering
  after returning to its tab.
- Pure shared display helpers explicitly use `cl def:pub` so Jac 0.34 exports
  them as browser functions instead of converting formatting into server calls.
- Uploads, publishing, identity confirmation, comments/votes, phone layout, and
  the complete cross-tab hospital/reset rehearsal are not verified by this check.
  The backend's four existing demo tests cover the scripted update/reset logic.

## Anshu integration update

The original scaffold verification above describes the earlier tab split.
For the implemented Organizations/Map slice and its tested limits, read
`docs/PUBLISHING.md`. Other feature owners should retain their own UI work and
merge the additive shared contract rather than replacing shared files wholesale.
