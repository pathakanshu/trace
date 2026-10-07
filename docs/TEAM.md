# Team contract

## Ownership

| Owner | Feature folder / entry | Backend responsibility |
| --- | --- | --- |
| Aidana | `features/media/MediaTab.jac` | `walkers/evidence.jac` |
| Gabriel | `features/people/PeopleTab.jac` | `walkers/resolve.jac` |
| Miguel | `features/graph/GraphTab.jac` | `graph/nodes.jac`, `graph/edges.jac`; coordinate schema changes with producers |
| Anshu | `features/organizations/OrganizationsTab.jac`, `features/map/MapTab.jac` | `walkers/ingest.jac`, `services/geo.jac`; shared integration |

Anshu coordinates `main.jac`, `jac.toml`, `services/`, `investigation/`,
`integrations/`, `walkers/watch.jac`, `demo/`, `components/`, shared styles, and
integration tests. Ownership is a coordination agreement, not an access restriction.

## Tab contract

All five entry components accept `snapshot` and `onRefresh`; Map also accepts
`active`. `snapshot` is the read-only `DashboardSnapshot` from
`services/trace.jac`. After a successful mutation, `await onRefresh()` so every
tab and the activity sidebar receive the same updated graph.

Tabs stay mounted to preserve drafts, search, selection, and map viewport.
Switching tabs does not navigate or reload. Do not copy the snapshot into local
state or call `window.location.reload()`. The shared shell also mounts the
optional `InvestigationPanel` under People; its result is separate from the
shared snapshot and does not change source claims.

Keep feature components, helpers, adapters (`services.jac`), and focused tests
(`test_*.jac`) in the feature folder. Use explicit `sv import` for server adapters.
Pure shared browser helpers use `cl def:pub` so Jac 0.34 does not turn them into
server calls. Shared presentation lives in `components/shared/Display.jac`.
Do not import another tab's UI or depend on it to save data.

Media reads `snapshot.media_records`, including upload details and contributions.
Each media mutation refreshes the same snapshot used by Graph and the other tabs.

All persistent types belong in `graph/`, with existing walker entry points in
`walkers/`. The Graph tab reads the same graph; it does not own a separate store.
For a new server action, coordinate the function import/registration in
`main.jac` and snapshot changes with Anshu, and schema/relationships with Miguel
and the producer. Prefer additive fields with defaults while branches still
consume the shared interface. Extend reset and its isolation checks for new types.

Use [the publishing contract](PUBLISHING.md) for source/report/alert behavior and
[the investigation guide](INVESTIGATION.md) for the report checker.
Current feature limits live in [LIMITS.md](LIMITS.md); evidence and product rules
live in [AGENTS.md](../AGENTS.md).

Graph tab: `get_dashboard()` sets `snap.graph = build_graph_snapshot(incident,
snap.duplicates)`, a read-only projection of the incident. Edge status is
`stored` (a typed edge), `confirmed`/`rejected` (a human identity review via
`IdentityDecision -Reviews-> Person`), `candidate` (ResolveWalker results, never
stored), or `derived` (`ActivityEntry.target_ids` or `Alert.claim_id`, never
stored). WatchWalker should create `Claim -Triggered-> Alert` next to `Receives`;
until it does, the Graph tab draws the derived `Alert.claim_id` link.

## Merge workflow

1. Use one branch per owner: `codex/aidana`, `codex/gabriel`, `codex/miguel`,
   `codex/anshu`. A shared mutable JacHammer workspace is not Git isolation.
2. Keep feature changes in owned folders and assigned walkers. Coordinate shared
   interfaces before depending on them; preserve teammates' uncommitted work.
3. Integrate small working slices frequently. Resolve conflicts locally rather
   than replacing shared files wholesale; run feature and integration checks.

## Manual acceptance checks

- Switch through all five tabs: one visible panel, unchanged URL/document.
  Left/Right and Home/End move tab focus and selection; hidden panels cannot take focus.
- Search People and Media; switch away/back and verify both queries remain.
- Pan/zoom/select Map, switch away/back: viewport, selection, and size remain correct.
- Publish the hospital example and retry it: every view receives the update,
  earlier reports remain, and the retry creates no extra claim or alert.
- Reset twice and rehearse again. Unrelated incidents/shared nodes survive.
- Without the live passphrase, a report check shows unavailability and the core demo works.
- At phone width, the tab strip scrolls, activity moves below the panel, and the
  document has no horizontal overflow.

These are acceptance steps, not a record that a particular revision passed them.
