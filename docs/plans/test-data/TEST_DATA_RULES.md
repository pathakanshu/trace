# Trace test-data specification, version 1

**This is a specification, not a generated dataset.** No people, reports, images,
fixtures, or runtime graph records are created by this change. It covers the
planned product, including features the current scaffold cannot import yet.

Read this together with [the quotas](quotas.json),
[the record contract](record-contract.md), and
[the generation prompt](TEST_DATA_GENERATOR_PROMPT.md). Requirements using MUST
are acceptance criteria. Counts describe the complete authored catalog after
all replay steps, not everything visible at the start of the demo.

Scope reviewed: `AGENTS.md`, `docs/TEAM.md`, `docs/PUBLISHING.md`, the existing
graph/walkers and five feature folders, the supplied “JacHacks A2Tech Win Plan:
CrisisGraph” and “JacHacks UMich Hacker Guide” PDFs, and the supplied hackathon
postmortem context. The plan is reference material; current user instructions
and the corrected provenance/status rules take precedence over its older
examples. No event eligibility or submission deadline is inferred from this
data specification.

## 1. Historical scenario and the boundary of the simulation

Working assumption: **the night of 5 July 2016 Bhote Koshi flood in
Sindhupalchok**, not a different Bhote Koshi flood or the Rasuwa/Trishuli river
system. Confirm this assumption when starting dataset work. If the user specifies another
event, revise the geography, bibliography, and clock before generation.

The resulting presentation must say:

> Trace exercise based on the 2016 Bhote Koshi flood. Historical context is cited.
> People, organizations, reports, media, and response activity are fictional.
> The 1,000-person workload is a counterfactual test scale, not a historical count.

This distinction matters: the contemporaneous ICIMOD account reports successful
evacuation without loss of life. It describes damage and threatened settlements,
not a verified list of 1,000 missing people. Do not borrow names of witnesses,
victims, officials, or relatives from historical reporting for fictional cases.
[ICIMOD, 13 July 2016](https://www.icimod.org/article/after-bhotekoshi/).

Use these sources for separate historical context, with their publication dates:

| Reference | What it supports | Temporal limitation |
| --- | --- | --- |
| [ICIMOD: After Bhotekoshi, 13 July 2016](https://www.icimod.org/article/after-bhotekoshi/) | Early account of impacts, evacuation, and uncertainty about the cause | Preserve the uncertainty expressed at publication |
| [ICIMOD: Caught amidst a flash flood in Bahrabise, 29 August 2016](https://icimod.org/caught-amidst-a-flash-flood-in-bahrabise) | Field observations of damaged roads, riverbanks, monitoring equipment, and downstream communities | Its later field visit and local rainfall episode are not automatically observations from 5 July |
| [ICIMOD: When the levee breaks, 16 May 2019](https://www.icimod.org/when-the-levee-breaks-reducing-glof-risks-through-dam-breach-modelling/) | Retrospective identification of a glacial lake outburst flood | Later analysis must not appear as knowledge available during the July 2016 exercise |
| [Sattar et al., Scientific Reports, 20 July 2022](https://www.nature.com/articles/s41598-022-16337-6) | Event date, Gongbatongsha origin, transboundary pathway, infrastructure impacts | Research reconstruction, not contemporaneous operational telemetry |

Keep a historical-reference ledger outside the fictional report corpus. Each
entry needs URL, title, publisher, publication date, retrieval date, paraphrased
supported statement, event-time precision, and scope/uncertainty. Cite exact
passages or figure numbers without copying whole articles. Real contextual
places may be named; invented hospitals, police posts, relief organizations,
bulletins, and capacities must visibly include “Exercise” or “Demo.” Do not use
real agency logos or fabricate publications at real agency URLs.

The event is a factual setting for a response-information exercise. This is
**not a hydrodynamic reconstruction**: no invented flood depth, discharge,
inundation polygon, evacuation route, or forecast may be called measured or safe.
Do not mix 1981, the 2014 Jure landslide, the 2015 earthquake, or Rasuwa events
into 2016 claims without a dated, explicit historical-reference relationship.

## 2. Exact scope and record budget

The primary exercise has one incident. Every identity has at least one initial
MISSING report; some later have other reported statuses. “1,000 people” therefore
does not mean 1,000 people remain missing at the final checkpoint.

| Catalog item | Exact count | Purpose |
| --- | ---: | --- |
| Distinct fictional individuals, evaluator only | 1,000 | Coverage and hidden identity truth for testing |
| Public Person records | 1,150 | Includes independently submitted aliases and duplicate records |
| Organizations | 32 | 6 police/rescue, 8 hospitals, 8 NGOs, 4 government coordination, 6 community/news groups |
| Sources, each an immutable report/publication | 1,800 | 1,400 institutional, 400 individual/community reports |
| Claims | 3,600 | 2,800 person; 200 infrastructure; 150 hazard; 150 aid; 100 facility; 150 media; 50 organization |
| Image uploads and actual image files | 200 | 120 original controlled scenes plus 80 copies/transformations |
| Locations | 1,000 | 840 initial observation points, 120 shared sites, 40 areas |
| Facilities | 36 | 8 treatment sites, 12 shelters, 8 aid distribution sites, 8 coordination/communications sites |
| Infrastructure subjects | 30 | 10 road segments, 8 bridges, 6 power assets, 6 water/communications assets |
| Hazard subjects | 18 | 8 flood observations, 6 slope/debris observations, 4 access/secondary-risk observations |
| Aid subjects | 40 | 20 needs, 12 offers, 8 deliveries |
| Contributors | 80 | Pseudonymous exercise accounts; never actual contact details |
| Contributions | 240 | Comments, corrections, translations, geolocation proposals, citations, challenges, task submissions |
| Votes | 360 | Feedback on contributions, not truth or identity decisions |
| Community tasks | 96 | 24 each: geolocate, translate, find earlier copy, source/challenge a claim |
| Subscriptions | 150 | 100 people, 20 locations, 10 media, 10 incident, 10 organizations |
| Saved investigations | 24 | Cited collections, comparisons, gaps, and research questions |

Separate evaluator/replay specifications: 1,000 identity groups; 250 identity
pair benchmarks; 120 image-family definitions; 100 review actions; 12 narrative
scenarios; 40 research queries; 40 negative-input cases. These are **not** extra
live graph nodes. Candidate matches, verification signals, status changes,
alerts, exports, and walker activity are runtime outputs: prescribe expectations,
do not manufacture successful results or promise exact output totals before
running the corresponding implementation.

An optional video pack adds **12 actual short videos and 36 derived frames**,
outside the 200-image budget. Six controlled source clips plus six declared
re-uploads; extract three frames from each source clip and three from each copy.
Record source clip and exact frame offset for all 36. No faces, injuries, or
distressing imagery. Unsupported video/frame matching must report unsupported,
not pass by comparing descriptions. The base dataset must work without this pack.

A separate isolation pack contains 2 fictional control incidents, 10 additional
people (5 each), 2 additional organizations (1 each), 2 sources (one per incident),
and 10 claims (5 per source). No new images. Include a colliding name and reused
report reference across incidents. These are excluded from every primary quota,
hidden from the judge's primary incident filter, and preserved by primary reset.
One explicitly shared organization link is added during a reset test; it must
not permit claims about a control person to enter the primary incident.

## 3. Files and storage: one graph, reproducible input files

Project root on this machine: `/Users/anshu/Developer/jachacks/trace`.
Paths below are a proposed contract; generation/import tooling is not implemented.

```text
docs/plans/test-data/                       # specifications only
  quotas.json
  record-contract.md
  trace-record.schema.json
demo/datasets/bhotekoshi-2016-exercise-v1/     # create in a later generation task
  manifest.json
  records/<kind>/part-0001.jsonl              # portable, normalized catalog
  raw/reports/<source-id>.json|txt            # original, immutable fictional inputs
  context/historical-references.jsonl        # real facts + citations, separate layer
  context/geography.geojson                  # sourced contextual anchors/river, provenance
  licenses.json                              # asset generation/licensing ledger
  validation-report.json                     # actual validator output, not self-attestation
demo/assets/bhotekoshi-2016-exercise-v1/
  images/<media-id>.<extension>               # 200 real files, later
  thumbnails/<media-id>.webp                  # derived display assets; not extra uploads
  videos/                                   # optional pack
  frames/                                   # optional pack
tests/fixtures/bhotekoshi-2016-exercise-v1/     # server/test-only; never a browser asset directory
  oracle/identities.jsonl
  oracle/identity-pairs.jsonl
  oracle/media-families.jsonl
  oracle/checkpoints.jsonl
  replay/scenarios.jsonl
  replay/actions.jsonl
  queries.jsonl
  invalid-inputs.jsonl
  control/records.jsonl
.jac/                                       # Jac-managed, ignored runtime storage
```

Text catalogs, contracts, and small evaluation files can be committed after
generation. Store the binary asset bundle outside ordinary Git commits by
default; distribute a versioned local/archive artifact with a checksum and copy
it into `demo/assets/...` on each laptop. Decide Git LFS only if the team actually
needs it. Future generation must add an appropriate asset ignore rule before
writing files. Do not commit dependency caches, credentials, runtime databases,
or generated browser bundles.

**Actual persistent graph storage currently lives under `.jac/data/`, including
`anchor_store.db` and `main.db`.** Let the installed Jac runtime manage those
files. Do not write fixture JSON into them, invent SQL tables, add another
database, or check them into Git. A future importer reads the catalog, executes
Jac graph mutations/walkers, and records fixture ID → Jac `jid()` mappings in
server-side runtime state. A file path is not a graph ID.

The app serves approved image assets through its own configured asset mechanism.
Do not expose `tests/fixtures`, raw private evaluator files, local absolute paths,
or the complete project directory to the browser. UI records receive resolvable
asset URLs from the adapter; the fixture stores portable project-relative paths.
All five tabs read the same persisted graph. Feature folders must not each get
their own competing copy of the data.

## 4. Generation format and deterministic rules

- Use UTF-8 JSONL, one complete object per line, no comments, NaN, Infinity,
  markdown fences, or trailing commas. Sort shards by stable ID. Maximum 100
  records per shard; zero-pad shard numbers. IDs are immutable, type-prefixed,
  six-digit counters; reserve control IDs from 900001 upward.
- Every primary record is explicitly fictional. Historical facts live in the
  separate reference ledger. Use `null` for unknown scalar values, `[]` for no
  relationships, and never empty strings as missing dates or fake coordinates.
- Use schema version `1.0`, dataset ID `bhotekoshi-2016-exercise-v1`, seed `20160705`.
  Record the generator version, seed, and asset tool/version in the manifest.
  A seed only reproduces deterministic sampling; generated media/LLM prose need
  their original outputs retained for repeatability.
  Record RNG implementation/version, sorted input order, sampling algorithm,
  zone quotas, rejection rules, retry limit, rounding stage, and geographic-input
  checksums. The later generator must supply this implementation; it does not
  exist merely because a seed is specified.
- Store known times as ISO 8601 UTC with `Z`. Display Nepal time as
  `Asia/Kathmandu` (UTC+05:45); do not round it to +05:30. Preserve original time
  text and precision. Unknown time is null; date-only time stays date-only in
  its original field, never a made-up midnight timestamp.
- The chosen **exercise clock**, not a claimed flood onset measurement, is
  `2016-07-05T12:15:00Z` (18:00 Nepal time). Replay checkpoints are T+0, +6, +12,
  +24, +36, +48, +72 hours. Historical event date is 2016-07-05 with “night”
  precision. Document that the exercise clock is arbitrary.
- Separate event/observation time, source publication time, catalog availability
  time, and actual runtime ingestion time. Late reports must not be backdated as
  if the app knew them earlier. Catalog `available_at` is the simulated release
  time. Runtime `ingested_at` is when import actually occurred; replay maintains
  a separate logical clock. Never put 2022 findings into a 2016 source.
- Preserve source content verbatim once authored. Correct it with a new report
  reference and a typed correction link; keep the old record. Compute hashes
  from bytes in code. Never ask an LLM to guess hashes, dimensions, EXIF, file
  sizes, coordinates, or successful tool execution.
- Foreign keys must resolve to the correct kind and incident. No dangling
  references, self-references where prohibited, source-lineage cycles, duplicate
  IDs, accidental cross-incident edges, or contradictory copies of the same ID.

Use the following hidden identity-level checkpoint targets to give the timeline
visible change. These are evaluator expectations, never precomputed UI totals:

| Checkpoint | Individuals reported so far | Missing | Safe | Injured | Unresolved |
| --- | ---: | ---: | ---: | ---: | ---: |
| T+0 | 0 | 0 | 0 | 0 | 0 |
| T+6 | 300 | 300 | 0 | 0 | 0 |
| T+12 | 1,000 | 1,000 | 0 | 0 | 0 |
| T+24 | 1,000 | 850 | 100 | 20 | 30 |
| T+36 | 1,000 | 760 | 160 | 40 | 40 |
| T+48 | 1,000 | 690 | 210 | 50 | 50 |
| T+72 | 1,000 | 650 | 250 | 50 | 50 |

T+0 is before the first report batch. The presentation's default reset state is
T+12, with all 1,150 Person records and their initial MISSING claims available;
later status changes, identity reviews, and the hero hospital report are held
back for replay. All subscriptions needed for the hero are active before its
update. Raw reports and all claims they assert share a release batch. A forward
reference is allowed in the full catalog only when importer ordering satisfies
it at that checkpoint; future claims or evidence must not leak into an earlier
snapshot. Public record/group counts are computed from that visible graph and
can differ from the hidden-individual totals in this table.

## 5. People: identity uncertainty and useful status timelines

Exactly 865 individuals have one Person record, 120 have two, and 15 have three:
`865 + 120 + 15 = 1,000`; `865 + 240 + 45 = 1,150` public records. Each Person
record gets an initial MISSING claim. The primary record of each individual is
not identified publicly. There is no public `true_person_id`, duplicate flag,
canonical identity group, oracle outcome, or stored authoritative `status`.

The 2,800 person claims consist of 1,300 MISSING, 550 SEEN_AT_LOCATION, 600
FOUND_SAFE, 200 INJURED, 10 DECEASED, and 140 PERSON_DETAIL. The ten death reports
are fictional, disputed rumors with explicit challenges and no confirmed-death
outcome; they test sensitive uncertainty handling. They are not historical death
claims. Final evaluator summaries over hidden individuals: 650 latest reported
missing, 250 latest reported safe, 50 latest reported injured, 50 unresolved.
Among the unresolved groups, 25 have opposing statuses with equal known times
and 25 have a competing report with unknown time. Death-rumor cases belong to
these 50, with conflicting equal-time or unknown-time evidence. A challenge
alone does not prove a rumor false. These buckets are fixture design, not
measured disaster statistics.

Rules for content:

- Use culturally plausible fictional names, Nepali and Latin-script variants,
  aliases, spelling errors, ±1 age discrepancies, unknown ages, non-unique
  surnames, and households with similar descriptions. Do not systematically
  associate an ethnicity, gender, or age group with rumor or unreliability.
- Across 1,000 identities: 160 aged 0–17, 610 aged 18–59, 180 aged 60–90,
  50 age unknown. These are chosen coverage quotas, not local demographics.
  Public report ages can vary; oracle age is only for validation. At least 30
  records have explicit accessibility or language-support needs, as attributed
  reports rather than medical diagnoses.
- Include 85 hard-negative candidate pairs: same/similar name with conflicting
  age, distinctive clothing, location/time, household, or independently known
  context. Never use appearance/face embeddings as identity proof. At least 20
  hard negatives share both a name and age; name+age must not auto-merge them.
- Hidden pair benchmark: all 165 same-individual pairs (120 double pairs plus
  45 pairs within triples), plus 85 hard negatives = 250. This is an evaluation
  set, not a prefilled resolver output list.
- Replay 80 correct identity confirmations forming an acyclic forest and 20
  rejections of hard negatives, each with actor, time, evidence, and reason.
  Do not expose a third record's identity merely because two records matched.
  Remaining associations stay unreviewed. The live UI cannot claim it deduced
  all 1,000 identities; after 80 joins it can show 1,070 review groups from
  1,150 records if every specified confirmation has actually been implemented.
- A later dated FOUND_SAFE report ordinarily updates the cited summary while
  retaining older MISSING history. It is not automatically a contradiction.
  Equal-time disagreement and unresolved undated reports require review.
  Newer ingestion of an older report must not reverse a newer known status.
- Every claim text must agree with its subject, structured assertion, and source
  wording, except explicitly identified adversarial-input tests outside the
  accepted corpus. A statement about “three people” cannot become three named
  individuals without separate support.

## 6. Reports, institutions, and the broader disaster graph

Source cardinality is exact: 900 reports assert one claim, 500 assert two,
300 assert four, 100 assert five. This yields 1,800 sources and 3,600 claims.
Use 1,260 structured CGX-style JSON originals and 540 pasted-text originals.
The normalized fixture contract is **not itself an already supported CGX API**;
an adapter must document the actual accepted fields. CSV, HTML, PFIF, and feeds
are optional capability tests outside these counts, never claimed supported
without a tested parser.

Of the 1,800 reports, 1,350 are independent authored reports and 450 are declared
relays/citations/corrections referencing earlier reports. Dependency links form
a DAG. Reposts of one report are not multiple independent witnesses. Preserve
unknown dependence as unknown if an association is discovered only later;
hidden construction lineage must not secretly drive the user-facing graph.

Each source has exactly one publisher: an Organization or a Contributor.
Institutional sources number 1,400; contributor sources 400. Every organization
has at least 15 reports, several times, and more than one subject. At least four
organizations each cover people, facilities, and access/aid topics. Include a
published correction, delayed bulletin, unclear timestamp, stale notice,
capacity update, and clearly attributed relay. No single organization owns all
corroborating evidence.

The additional 800 claims are about real product scope, not decorative nodes:

| Subject kind | Claims | Required changes and disagreements |
| --- | ---: | --- |
| Infrastructure | 200 | Access blocked/open/restricted, bridge inspection, power/water/communications outage and restoration |
| Hazard | 150 | Reported flood/debris activity, contradictory location, receding observation, uncertainty about cause |
| Aid | 150 | Needs, available supply, dispatch and delivery claims; quantity with explicit unit |
| Facility | 100 | Open/closed, reported capacity and occupancy, services available, update time |
| Media | 150 | Claimed capture time/location, reused caption, source/copy attribution; no automatic authenticity verdict |
| Organization | 50 | Service/contact-point availability and bulletin corrections |

Facilities, assets, hazards, and aid entries are typed subjects. Their conditions
come from Claims. Do not model a bridge as a Person to squeeze it through today's
`About` edge. Quantities must be nonnegative and comparable only in matching
units. Occupancy can exceed capacity only when the source explicitly reports
overcrowding; conflicting counts must retain both sources. Needs/offers/deliveries
are separate objects linked by sourced claims, not falsely balanced inventory.

## 7. Map distribution and heatmap semantics

Use the **Kodari/Tatopani–Bhote Koshi–Bahrabise–Lamosanghu/Khadichaur corridor** as
the primary setting. The contextual upstream origin is transboundary; do not
force Gongbatongsha or Tibet river geometry inside a Nepal district polygon.
Kathmandu-area receiving facilities may appear as fictional exercise sites,
not flood-hit neighborhoods. Verify river connectivity and settlement anchors
from cited geographic sources before sampling. A bounding rectangle alone is
not a geographic validation. Never reuse the old demo's two coordinates as
verified historical positions.

For each of the 1,000 hidden individuals, the first report has exactly one of:

| Spatial precision | Individuals | Display behavior |
| --- | ---: | --- |
| Approximate point observation | 840 | Includes an explicit uncertainty radius and basis |
| Area only | 100 | Region count/polygon; never a fabricated point centroid |
| Location unknown | 60 | Unmapped counter and case list |

The 840 initial points are allocated to authored scenario clusters: 240 around
the Kodari/Tatopani sector, 220 along the intervening inhabited river/road
corridor, 220 around Bahrabise, 120 around the downstream
Lamosanghu/Khadichaur sector, and 40 sparse accessible corridor observations.
These weights make a legible exercise; they are not observed population or
damage measurements. Draw truncated clusters around verified inhabited/place
anchors, not uniform random points throughout Nepal or circles on steep empty
mountainsides. Use seeded sampling; reject water, inaccessible slope, and
out-of-area positions when applicable land/settlement data is available. If
terrain validation is unavailable, say so and use verified settlement anchors
with larger uncertainty, not invented terrain certainty. Several observation
Location records may share the same approved settlement coordinate; record
`coordinate_method=settlement_anchor` and do not jitter them into unverified
surroundings. A sampled point uses `coordinate_method=sampled_in_approved_zone`.

**Geography readiness gate:** before placement, complete and review
`context/geography.geojson` with stable feature IDs, ordered place anchors,
approved reporting-zone polygons, a verified river path, source URL/feature ID,
geometry/version date, retrieval date, license/use conditions, precision, and
checksum. Text citations above establish place relevance, not every coordinate
or sampling mask. If these inputs cannot be verified, geographic generation is
blocked; continue independent text planning and do not invent the geometry.

The location catalog contains these 840 point Locations plus 120 shared sites
and 40 area Locations. The shared sites cover the 36 facilities, 30 assets,
18 hazards, and 36 additional meeting/observation sites. Area polygons may be
reused by multiple subjects. Movement/updates reuse this catalog so the exact
count remains 1,000. At least 60 people have later observations at shared sites;
at least 20 have conflicting location proposals. No public table exposes hidden
individual-to-cluster or identity-group truth.

Each geometry needs a place label, country, current administrative references,
geometry/precision, coordinate provenance, and uncertainty. Modern boundaries
in the existing map are a display reference, not proof of 2016 administrative
boundaries. Store WGS84 GeoJSON `[longitude, latitude]`, not reversed pairs.
Polygons must be closed and valid; point-in-polygon checks must include holes.
Follow [GeoJSON RFC 7946](https://www.rfc-editor.org/rfc/rfc7946).
The existing full `geometry.topo.json` identifies Sindhupalchok as district ID
30, province ID 3. Validate against its actual geometry, not only its bounding
box and not the simplified UI geometry. Primary corridor observation points use
approved Sindhupalchok reporting zones; receiving sites use their own verified
administrative polygons; transboundary historical context uses its declared
country/geography. District 30 is not a blanket constraint on all geometries.
No `(0,0)`, NaN, or exact-looking
coordinates for unknown locations. Keep at most five decimal places for sampled
points; numerical precision does not imply accurate observation.

Heatmap requirements for the future implementation:

1. Default layer: **reported missing case groups at the selected replay time**.
   Count each visible, human-confirmed identity group once, with weight 1, using
   its selected cited location. Unreviewed duplicate records remain separate
   groups and the legend states that overlap is under review. The hidden oracle
   must never silently deduplicate a public heatmap.
2. A separate “report activity” layer counts claims; a separate “media uploads”
   layer counts uploads. Never label either as number of people. Reposts and
   independent sources are distinguishable in the evidence drawer.
3. Conflicting point locations show disagreement/uncertainty and are excluded
   from the default point heatmap until a cited selection is made. Area-only and
   unknown cases remain visible as counters/region layers; do not scatter them
   as invented points. Explain all exclusions so totals reconcile.
4. Use the same scale/domain, bandwidth, viewport, and inclusion policy when
   comparing time checkpoints. The replay must visibly change as safe reports
   arrive and movement is reported. Intensity is report density, not flood
   severity, death risk, or a routing recommendation.
5. Keep facilities, reported hazards, access segments, and contextual river as
   optional layers. Link every clicked feature to sources, time, uncertainty,
   and related graph records. Do not create lines between places and call them
   roads or evacuation paths without sourced geometry.

## 8. Media: files, provenance, and honest tool tests

Create exactly 120 base scenes: 35 infrastructure/access, 25 hazards, 25
facilities/aid, 20 notices/documents, 15 personal possessions or non-identifying
illustrations. All are controlled synthetic/staged assets, visibly labeled as
exercise content in the UI and asset ledger. No actual missing-person photos,
face matching, graphic injury, scraped personal profiles, or real victim names.
Store originals so independent runs use identical bytes. Do not call generated
images documentary photographs of the 2016 event.

Create exactly 80 additional uploads: 40 byte-identical copies, 20 resized
copies, 10 JPEG re-encodings, and 10 crops. Use disjoint family classes:
40 base-plus-exact families, 20 base-plus-resize, 10 base-plus-reencode,
10 base-plus-crop, and 40 singletons. Each extra derives directly from its one
base; no family contains several transformation classes. The 200 files have
exactly **160 distinct SHA-256 hashes**
when transformed files genuinely change bytes and base hashes are distinct.
Build 120 held-out family records. Transformation parameters and hidden lineage
belong in that oracle, not in captions, public filenames, or resolver features.
Safe generic media IDs must not encode duplicate groups. An intentional declared
repost can expose its cited predecessor; that is different from hidden lineage.

Metadata coverage over the 120 base assets: 36 deliberately embed controlled
synthetic EXIF GPS, 24 contain non-GPS EXIF only, 60 contain no EXIF. Record actual
extracted metadata later; derived copies may strip or preserve metadata according
to their recorded transformation recipe. Within the 36 GPS bases, 12 have a
conflicting fictional caption location. At least 20 other uploads invite
community location proposals. A GPS tag is editable metadata, not verified truth.

Use 20 of the 40 singleton families for 10 unrelated visually similar pairs as
negative matches. Put misleading captions on 10 exact-copy publications and
10 resized-copy publications while preserving their upstream originals. Include
at least 10 old/unknown capture-time cases,
and 5 families whose earliest published copy is ingested last. These are
overlapping scenario tags, not additional files. A current generated file may
have an exercise-reported 2016 capture time; store its actual creation time
separately and clearly mark any deliberately embedded test timestamp as synthetic.

Actual verification output needs check name/version, actor/tool, run time,
input hashes/parameters, result, supporting evidence, limitations, and one of
`not_run`, `completed`, `unavailable`, `unsupported`, `error`. Only `completed`
can carry a substantive check outcome. Exact hash matching must work; near-copy
and crop matching remain capability tests with measured failures, not promises.
No invented C2PA signatures, SynthID results, reverse-image-search hits,
geolocation certainty, or AI-generated probability. Missing credentials do not
prove fakery, and no detector proves an image human-made. Say “earliest known
copy,” never “the original” without evidence.

Produce thumbnails after hashing originals. Use 1,280–1,920 px long-edge base
images, 320 px thumbnails, a 250 MiB base asset budget, and a 100 MiB optional
video budget. Document any necessary deviation. Corrupt, truncated, missing,
oversized, traversal-path, and unsupported files belong in the negative-input
pack, outside the valid 200-image corpus. No invented file URI, hash, or license.

## 9. Community work, subscriptions, and research

The 240 contributions comprise 70 comments, 30 corrections, 30 translations,
40 geolocation proposals, 25 earlier-copy citations, 25 source citations, and
20 challenges. Task submissions reference these same contributions; do not
create extra duplicate records. Contributions are attributable internally, but
exactly 60 use anonymous public display. Contributors are pseudonymous accounts,
not automatically affected Person nodes. Keep originals and translations; flag
machine translation and human review distinctly. At least 40 contributions
include Nepali text with an English rendering; do not claim native-speaker review
unless someone actually reviewed it.

Exactly 360 votes, one per `(contributor, contribution)`, no self-votes:
240 helpful and 120 not-helpful. Include high-vote weak evidence and low-vote
well-sourced evidence. Votes never confirm identity, prove a claim, or change
status. The 96 tasks end with 40 open, 20 in progress, 24 submitted, 12 reviewed;
submitted/reviewed tasks have actual linked contribution evidence and explicit
review attribution. Task completion alone is not correctness.

Subscriptions reference explicit subjects and contributor accounts. They
produce in-app alerts only; fictional addresses must never cause an email/SMS.
Include two followers on one hero person, a person with no followers, followers
of a reported location, and one contributor following several subject types.
Define idempotency on subscription + triggering event + alert kind. A quiet
baseline import must not flood the app with historical notifications.

The 24 investigations include six person timelines, six access/hazard questions,
six aid/facility comparisons, six media/source-lineage investigations. Each
has owner, title, query, selected source/claim IDs, gaps, and saved time.
Prepare 40 evaluator queries: 10 person-change, 8 geographic/access, 8
aid/facility, 8 media/lineage, 6 intentionally insufficient-evidence questions.
Each specifies required citations/time cutoff, acceptable uncertainty, and
forbidden unsupported conclusions. Any answer/export must cite claims actually
available at the chosen time; it must not quote an expected-answer file.

## 10. Twelve stories and an inspectable graph

Every story spans at least three tabs and has a beginning, an observable action,
and an expected consequence. Pick all records from the same catalog; do not
generate disconnected demo-only duplicates. Overlap between stories is useful.

| Story | Required behavior |
| --- | --- |
| 1. Maya's update | Two reports, explained candidate, human review, later hospital claim, actual subscription alert |
| 2. Same name, different people | Strong-looking name/age match rejected using conflicting context |
| 3. A family with three records | Two confirmed associations do not grant unreviewed evidence authority |
| 4. A viral bridge photo | Exact reposts collapse in a copy view while publication history remains inspectable |
| 5. Wrong location caption | Metadata, caption, and community proposal disagree; no automatic “verified” pin |
| 6. Earlier copy arrives late | Earliest-known publication changes without rewriting capture time or past ingestion |
| 7. Shelter capacity changes | Contrasting sources, update times, occupancy/capacity units, cited facility state |
| 8. Access and aid | Blocked access report linked to an affected facility and an aid need/delivery claim |
| 9. Anonymous correction | Public anonymity, retained provenance, review, and an explicit corrective claim |
| 10. Translation and source dependency | Original Nepali content plus translation; relays do not become independent confirmation |
| 11. Historical versus current disagreement | Late old MISSING report does not undo a newer safe report; equal/unknown times remain unresolved |
| 12. Failure and recovery | Optional evidence tool unavailable, core flow still works, retry adds no duplicate alert, reset is isolated |

For Maya, adapt the existing fictional character and migrate the scenario clock
consistently; do not copy current September 2026 timestamps into a 2016 exercise.
Reserve the hospital report for a replay action so judges can watch new nodes
and the alert actually appear. Show a separate equal-time/undated contradictory
report if demonstrating disagreement; the later hospital update alone is not
necessarily conflicting evidence.

Graph structure must be meaningful:

```text
Organization -> publishes -> Source -> asserts -> Claim -> concerns -> Subject
Contributor  -> publishes -> Source                  | -> located at -> Location
                                                    | -> cites -> Media
Source       -> relays/corrects -> Source
Contributor  -> contributes -> Contribution -> concerns -> Claim/Media/Subject
Subject      -> followed by -> Subscription -> receives -> Alert (runtime)
Media        -> evaluated by -> VerificationSignal (runtime)
```

The schema contract defines the exact stored references; the arrows here are a
conceptual projection, not an instruction to rename existing Jac edges. Require
all 1,150 people to have sourced claims; all 200 media uploads to have a Source;
at least 160 uploads to be cited by a claim; every non-person subject to have at
least one claim. At least 60 claims cite two or more media uploads and at least
100 cite one. No arbitrary friendship links or random edges to make the graph
denser. Preserve legitimate sparsity and unresolved evidence gaps.

First graph view should aggregate by source organization, subject kind, or
geographic cluster, with counts of underlying nodes/edges. Budget at most 150
visible nodes and 300 visible edges; an expanded story shows roughly 25–60 nodes.
Membership in an incident should not draw thousands of spokes. Clicking a
cluster must reveal real members, not a second invented graph. Use stable layout,
typed node shapes/colors, source-dependence links, and a brief animation of
actually added edges. Put labels on selected/focal nodes instead of every node.

The judge-facing moment is **one report changing the map, sourced timeline,
graph, and subscriber alert together**. A dense graph alone does not demonstrate
reasoning. The full dataset provides scale and context; a curated view explains
why the links matter.

## 11. Load profiles and current implementation gaps

Author the complete catalog, then select a **50-individual hero profile** with
all necessary references. Include 40 single-record, 8 double-record, 2 triple-record
identities (62 Person records), at least 24 image uploads covering all five copy
categories, all 12 stories, and every required publishing organization. Exact
derived source/claim/location counts come from dependency closure and must be
listed in its manifest. A closure includes required foreign keys and predecessors,
not every report an included organization ever published. Do not alter records
between profiles. The full profile includes the entire primary catalog.

Current code audit, `codex/anshu` at `2d074bd`:

| Gap | Required before claiming full-corpus support | Coordination owner |
| --- | --- | --- |
| `About` only targets Person; Source/Location types are thin | Typed subjects, reported-location/provenance fields, multi-claim report ingestion | Miguel + producers + Anshu |
| Map discovers locations through media only | Claim/subject locations and precision/uncertainty projections | Anshu |
| Resolver runs all person pairs on dashboard refresh | Candidate blocking/indexing, explicit runs, bounded/paged results; 1,150 records mean 660,675 pairs | Gabriel + Anshu |
| Snapshot and map load entire collections | Paged lists, bounded graph neighborhoods, map aggregation | All owners, Anshu integrates |
| Evidence currently simulates results and replaces signals | Real file checks, attributable immutable runs, honest unavailable states | Aidana |
| Identity review, MediaCopy, community work, general subscriptions are absent | Additive graph contracts and real actions; never preload fake successes | Respective owners + Miguel |
| Publishing/reset assume the named legacy demo | Explicit dataset/incident mapping, supported-type reset, safe historical/context separation | Anshu |

This document does not migrate that schema. Do not import the full corpus into
the current dashboard and assume performance or semantics are ready. An adapter
must report supported, deferred, and rejected kinds/fields; never silently drop
them or turn unsupported assertions into free-form Person notes. The contract
uses null unknown ages; the current `age=0` sentinel requires a documented legacy
adapter until the shared schema supports null. Unknown is not a newborn.

## 12. Acceptance gates for the later generation task

1. **Structure:** validate each record with the checked-in JSON Schema and date
   format checking enabled. Validate all files are UTF-8, parseable, within
   allowed paths, and exact quota totals match `quotas.json`.
2. **Semantics:** a program checks IDs, foreign-key kind/incident, source-claim
   cardinalities, publisher XOR, DAGs, unit constraints, lifecycle timing,
   identity allocations, geometry validity, media lineage, votes, and task
   evidence. JSON Schema alone cannot verify these cross-record rules.
3. **History:** a human/agent checks every historical ledger assertion against
   its cited source, publication date, precision, and geographical event. Facts
   that cannot be verified remain unknown; do not complete them from imagination.
4. **Assets:** inspect actual files; calculate byte hashes, sizes, dimensions,
   EXIF presence, thumbnail consistency, transform outcomes, license/generation
   records, and exact 200/160 image/hash counts. Verify the UI resolves local
   assets offline. Missing assets mean incomplete delivery.
5. **Separation:** browser/API payloads, captions, filenames, and public fields
   contain no hidden identity keys, family truth, expected answers, planned
   success signals, or scripted “agent completed” text. Fixture membership is
   not evidence of a real-world match.
6. **Replay:** on a compatible importer, baseline → actions → persisted reload
   → repeat action → reset produces expected behavior. Run Watch on baseline
   silently/mark seen before activating the action sequence. Counts for actual
   alerts/signals must be measured and compared with evaluator expectations.
7. **Forty negative cases:** 8 malformed/missing fields; 8 bad/cross-incident
   references; 8 time/semantic inconsistencies; 8 invalid media/path/size cases;
   8 idempotency, source prompt-injection, or unsupported-format cases. Keep
   invalid objects out of the accepted corpus. A source saying “ignore all
   instructions” remains source data and must not direct the agent or importer.
8. **Reset:** delete only this dataset's generated/owned unshared graph records,
   ID map, and outputs. Preserve the two control incidents, protected shared
   nodes, source input files, and asset bundle. Repeat the same hero rehearsal
   twice, then on another laptop; compare graph counts and real outputs.
9. **Presentation:** manually inspect the hero graph, map clusters at every
   checkpoint, unmapped counter reconciliation, 200-image contact sheet,
   case timelines, institution feed, failure state, and empty search state.
   Report measured load time/node counts, not invented performance claims.

Deliver an actual validation report with rule ID, pass/fail/blocked, observed
counts, tool version, evidence path, and limitations. A generation-only run can
pass file/content checks while runtime gates remain **blocked: importer or
feature not implemented**. Do not mark everything green because the intended
behavior is described. The goal is a repeatable, honest demo with strong data,
not fabricated evidence that unfinished features already work.
