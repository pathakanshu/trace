# Media — Aidana

Entry component: `MediaTab.jac`.

Own media search/upload, evidence display, and walkers/evidence.jac. Replace simulated results with actual bounded checks and explicit unavailable states.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
