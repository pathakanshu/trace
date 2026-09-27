# Media — Aidana

Entry component: `MediaTab.jac`.

Own media search/upload, evidence display, and walkers/evidence.jac. Replace simulated results with actual bounded checks and explicit unavailable states.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

## Unified media implementation handoff

The media adapter now exposes `upload_image`, `list_incident_media`, `check_media_duplicates`, `edit_media`, `delete_media`, `add_media_comment`, and `add_media_assertion` from `features.media.media_upload`. The existing `main.jac` imports only `UploadRecord`, `upload_image`, `list_image_uploads`, and `check_media_duplicates`. Before enabling the new UI, the integration owner must register the remaining functions in `main.jac` and expose/refresh the adapter results as needed.

Uploads are connected to canonical `graph.nodes.Media` via the existing incident `Contains` edge. Since the shared Media schema has no filename/source/comment/assertion fields, feature-owned `MediaMetadata`, `MediaComment`, and `MediaAssertion` nodes are associated with their Media record; comments/assertions are persisted as child graph records. Shared `MediaView` snapshots still omit uploaded bytes and feature metadata until coordinated integration updates them. Delete removes the Media node and descendants (comments, assertions, signals) and cleans duplicate ID metadata on other Media in the same incident.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.
