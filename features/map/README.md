# Map — Anshu

Entry component: `MapTab.jac`.

Own the map, places, map interactions, and services/geo.jac. Keep pins backed by graph locations; do not present them as live person locations.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
