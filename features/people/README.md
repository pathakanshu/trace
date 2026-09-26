# People — Gabriel

Entry component: `PeopleTab.jac`.

Own case search, report timelines, human identity review, and walkers/resolve.jac. Add corrections as sourced claims; never overwrite source history.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
