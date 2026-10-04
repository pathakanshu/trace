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

## Shared review gallery

`CommunityGallery.jac` adds 20 user-supplied photos and nine clips above the
incident-scoped records (expand **Incident records and uploads** to use them).
The shared gallery is visible from either incident. Files are not attributed to
the Bhote Koshi flood: source, recording date and location remain unverified.
Votes mean **useful for review**, never truth or verification. No EXIF or model
analysis is performed.

- Search title/original filename; filter photos/videos; sort by **Most useful**
  or **Newest added**. The supplied batch shares one ingestion timestamp; ties
  use the stable manifest order, not an asserted capture time.
- Initially 12 cards, then **Show more media** adds 12. Every preview is a lazy
  JPEG thumbnail (maximum 640px); full PNGs open only by clicking **Open full size**.
- Videos have no video element or source until **Play**. H.264 MP4 playback
  copies fit within 1280px, use fast-start metadata and `preload="none"`. Only
  the clicked clip is requested. Browsers may buffer that selected clip while
  playing; opening the gallery does not download the video collection.
  The tested Jac 0.34.1 static server ignores Range headers (200/full file), so
  this is click-to-load playback, not a byte-range streaming service.
- Usefulness counts persist in Jac's graph. A browser UUID stored under
  `trace-media-voter-v1` allows one removable vote per file. The graph retains
  its hash, not the browser key. Other browsers see counts after refresh.
  Clearing browser storage permits another vote; there is no identity or abuse
  protection. Storage-disabled browsers can still view the gallery.

`community.jac` registers canonical root-level `Media` and `MediaMetadata` nodes
idempotently from `community-manifest.json`. `MediaVote` children are defined in
`graph/media_votes.jac`. Shared library nodes stay outside incident projections,
subscriptions and reset. Resetting Maya preserves this gallery and its votes.
Deployments must preserve `.jac/data/` to retain votes through redeployments.
The lock protects one server process; multiple independent worker processes and
authenticated voting are outside this demo's guarantees.

`main.jac` registers both endpoints using:

```jac
import from features.media.community { CommunityMediaView, community_media, set_media_vote }
```

### Assets and preparation

Deploy the committed `assets/community-media/` directory with the manifest and
code. Jac 0.34.1 serves `/assets/` and includes these files in the web build.
The package has 29 primary files (131,992,315 bytes) and 29 JPEG thumbnails
(1,375,359 bytes). The nine playback clips total 64,929,477 bytes. Every original,
playback copy and thumbnail has a computed SHA-256 and byte count in the manifest.

Originals were moved intact from the root download folder into
`media-originals/user-supplied-20260927/` in Anshu's primary checkout. That ignored
336,244,450-byte folder is preserved locally, outside the deployed package.
PNG originals are also copied byte-for-byte into the package. MOV originals are
kept locally; their MP4 playback conversions are clearly identified in each
card's file details. The files are user supplied, not licensed stock or generated
exercise media; source and reuse rights have not been established.

`tools/prepare_community_media.py /path/to/originals` prepares a **new** package
with ffmpeg/ffprobe. It refuses to overwrite existing output; make a versioned
replacement deliberately when swapping assets. No media tools are required at
app runtime. `tools/verify_community_media.py --originals /path/to/originals`
recomputes hashes, sizes, dimensions, codecs, duration, thumbnail bounds and MP4
fast-start structure. Omit `--originals` for deployment-only checks.

### Checks

```sh
jac test features/media/test_media.jac features/media/test_media_integration.jac features/media/test_community.jac
python3 tools/verify_community_media.py
```

Browser regression (Playwright available locally, disposable server/store only):

```sh
TRACE_MEDIA_URL=http://localhost:8098 node features/media/verify_community.cjs
```

Optional `TRACE_BROWSER_EXECUTABLE` selects Chromium; `TRACE_MEDIA_SCREENSHOTS`
selects an existing directory outside the repo. `TRACE_MEDIA_RESULTS` selects a
JSON report path (default `/tmp/trace-media-browser.json`). The script rejects a
store with existing votes, writes its own test votes, then removes them even on
failure. It checks real network traffic, decoded thumbnails, playback, actual
range-response behavior, numeric sorting, pagination, browser persistence, independent
browser counts, undo, search and phone layout. It never calls a model.

See [the team contract](../../docs/TEAM.md) for shared interfaces and ownership.
