# Organizations — Anshu

Entry component: `OrganizationsTab.jac`.

Own institutional reports and publishing. Current cards group existing institutional Source claims; coordinate Organization nodes with Miguel before adding the publisher.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
