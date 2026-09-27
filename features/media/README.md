# Media integration

`MediaTab.jac` reads `DashboardSnapshot.media_records`; all mutations await the
shared refresh callback. Persistent media metadata, comments, and attributed
assertions are defined in `graph/nodes.jac` and attached to canonical Media nodes.

`media_upload.jac` provides upload/list, exact-duplicate checks, edits, deletion,
comments, and attributed assertions. All UI actions are registered in `main.jac`.
Uploads validate size and file signatures and hash decoded bytes with SHA-256;
this is not complete image decoding, EXIF extraction, or authenticity analysis.
Same filename/source/bytes retries reuse the existing upload; separate source
references preserve distinct copies and their `ExactCopyOf` relationship.
Upload time is separate from unknown capture time. Seed records stay labeled.

Only unreferenced uploads belonging to one incident can be deleted. Delete/reset
clean known child records while preserving externally shared data. Source-linked
seed records remain evidence. Comments and assertions are unauthenticated demo
contributions; they do not change person status or establish truth.

Run `jac test features/media/test_media.jac features/media/test_media_integration.jac`.
See [the team contract](../../docs/TEAM.md) for shared interfaces and ownership.
