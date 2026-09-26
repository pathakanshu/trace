# Organizations — Anshu

`OrganizationsTab.jac` reads institutional reports from the shared snapshot.
`PublishReport.jac` and its implementation provide a structured form, explicit
person selection, local preview, and publish/retry feedback. `services.jac`
validates IDs and content, calls IngestWalker, then runs WatchWalker.

These are fictional institutions, not authenticated publishers. Preserve each
report's original text and reference. Corrections use new references; exact
retries return the saved claim without another alert.

See [the publishing contract](../../docs/PUBLISHING.md) for shared additions and
[the team contract](../../docs/TEAM.md) for ownership. No uploads or LLM parsing
are implemented in this slice.
