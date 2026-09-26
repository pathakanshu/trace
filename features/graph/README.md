# Graph — Miguel

Entry component: `GraphTab.jac`.

Own relationship visualization and central graph/nodes.jac and graph/edges.jac definitions. Coordinate changes with claim producers. Render actual relationships; never maintain a second graph for this tab.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
