# Trace catalog record contract 1.0

This is a generation contract, not fixture data or an implemented importer.
Read [the rules](../../docs/TEST_DATA_RULES.md) and [quotas](quotas.json) first.
`trace-record.schema.json` is JSON Schema 2020-12 for **one JSONL object**.
There are **17** catalog kinds. All objects reject unknown fields. All listed
fields are required; only fields marked `?` may be `null`. Empty strings do not
mean unknown. `T[]` means an array of T, usually empty when no relation exists.
The schema is authoritative for spelling, enums, bounds and nested shape;
this document adds foreign-key, temporal and file semantics it cannot enforce.

## Common fields and notation

| Field | Exact type / meaning |
| --- | --- |
| `schema_version` | String constant `1.0` |
| `dataset_id` | String constant `bhotekoshi-2016-exercise-v1` |
| `kind` | One of the 17 lowercase kind names below |
| `id` | `<prefix>-<six digits>`; immutable; no embedded identity/family labels |
| `incident_id` | Incident ID; an Incident references its own `id` |
| `available_at` | UTC simulated release timestamp, whole seconds ending `Z` |
| `is_synthetic` | Boolean constant `true` |

Prefix map: `incident=inc`, `person=per`, `organization=org`, `source=src`,
`claim=clm`, `media=med`, `location=loc`, `facility=fac`, `infrastructure=inf`,
`hazard=haz`, `aid=aid`, `contributor=act`, `contribution=con`, `vote=vot`,
`task=tsk`, `subscription=sub`, `investigation=inv`. Primary IDs use counters
000001–899999; control IDs use 900001–999999. IDs are unique across shards.
A schema-valid ID is not proof that its referenced record exists.

`UTC` means `YYYY-MM-DDTHH:MM:SSZ`, a real date with format checking enabled.
`Text` means nonempty UTF-8 text; `ID(kind)` has the relevant prefix. `Ref` is
exactly `{kind, id}`, with the ID prefix matching kind. `SubjectRef` allows
incident/person/organization/media/location/facility/infrastructure/hazard/aid.
`EvidenceRef` additionally allows source/claim/contribution. `PublisherRef`
allows organization or contributor. These are typed references, not inline nodes.

`Time` is exactly `{value: UTC?, date: YYYY-MM-DD?, precision, original_text:
Text?, timezone: Text?, range_start: UTC?, range_end: UTC?}`. `precision` is
`second|minute|hour|date|night|range|unknown`. Second/minute/hour require `value`
and `original_text`, with other date/range fields null. Date/night require `date`
and `original_text` with no fabricated UTC instant. Range requires ordered start
and end plus original text. Unknown has null value/date/ranges. Preserve supplied
wording; timezone is an IANA name when known. A timestamp with minute/hour
precision denotes that interval, not a more precise observation. Do not order
uncertain intervals as exact instants. Fixture ages and times are source reports.

`Review` is exactly `{contributor_id, reviewed_at: UTC, note: Text,
evidence_claim_ids: ID(claim)[]}`. This is an attributed fictional exercise
review, not a claim that a real native speaker reviewed generated language.
Actual linguistic QA belongs in the validation report.

## Kind-specific fields

The following fields are additional to the seven common fields. Named nested
objects are defined here or under `$defs` in the schema. No `status`,
`true_person_id`, `is_duplicate`, `family_id`, `confidence_score`, expected answer,
or fabricated tool-result field may be added to public records.

| Kind | Exact fields and types |
| --- | --- |
| `incident` | `name: Text`, `description: Text`, `event_time: Time`, `exercise_clock_start: UTC`, `display_timezone: "Asia/Kathmandu"`, `historical_reference_ids: hist-ID[]` (primary nonempty; controls may be empty) |
| `person` | `display_name: Text`, `name_variants: Text[]`, `reported_age: integer 0..130?`, `description: Text?`, `support_needs_claim_ids: ID(claim)[]` |
| `organization` | `name: Text`, `organization_type: POLICE_RESCUE\|HOSPITAL\|NGO\|GOVERNMENT\|COMMUNITY_NEWS`, `description: Text` |
| `source` | `title: Text`, `publisher: PublisherRef`, `source_type: POLICE_RESCUE\|HOSPITAL\|NGO\|GOVERNMENT\|COMMUNITY_NEWS\|INDIVIDUAL`, `report_reference: Text`, `published_at: Time`, `original_language: language-tag`, `raw_format: structured_json\|pasted_text`, `raw_path: path`, `raw_sha256: SHA256`, `dependencies: SourceDependency[]`, `dependency_disclosure: no_dependency_declared\|declared\|unknown` |
| `claim` | `source_id: ID(source)`, `subject: Ref` (seven claim subject kinds below), `assertion: Assertion`, `reported_at: Time`, `provenance: Provenance`, `location_id: ID(location)?`, `supporting_media_ids: ID(media)[]`, `corrects_claim_ids: ID(claim)[]`, `related_claim_ids: ID(claim)[]` |
| `media` | `media_type: image\|video\|frame`, `source_id: ID(source)`, `description: Text`, `published_caption: Text`, `reported_capture_time: Time`, `claimed_location_id: ID(location)?`, `asset_path: path`, `sha256: SHA256`, `byte_size: positive integer`, `mime_type: image/jpeg\|image/png\|image/webp\|video/mp4`, `width_px: positive integer`, `height_px: positive integer`, `duration_seconds: positive number?`, `actual_created_at: UTC`, `license_id: lic-ID`, `is_controlled_exercise_asset: true`, `embedded_metadata_is_synthetic: true`, `thumbnail_path: path?`, `declared_predecessor_media_id: ID(media)?`, `frame_origin: FrameOrigin?` |
| `location` | `name: Text`, `country_code: ISO alpha-2`, `admin_refs: AdminRef[]`, `geometry: Geometry`, `precision: approximate_point\|site\|area`, `catalog_role: initial_observation_point\|shared_site\|area`, `coordinate_method: settlement_anchor\|sampled_in_approved_zone\|contextual_site_reference\|authored_exercise_area\|controlled_asset_metadata\|contributor_proposal`, `uncertainty_radius_m: number >=1?`, `coordinate_provenance: LocationProvenance` |
| `facility` | `name: Text`, `facility_type: TREATMENT\|SHELTER\|AID_DISTRIBUTION\|COORDINATION_COMMUNICATIONS`, `location_id: ID(location)`, `operator_organization_id: ID(organization)?` |
| `infrastructure` | `name: Text`, `infrastructure_type: ROAD_SEGMENT\|BRIDGE\|POWER\|WATER_COMMUNICATIONS`, `location_ids: ID(location)[]` (nonempty), `operator_organization_id: ID(organization)?` |
| `hazard` | `name: Text`, `hazard_type: FLOOD\|SLOPE_DEBRIS\|ACCESS_SECONDARY`, `location_ids: ID(location)[]` (nonempty) |
| `aid` | `name: Text`, `aid_type: NEED\|OFFER\|DELIVERY`, `location_id: ID(location)?`, `organization_id: ID(organization)?` |
| `contributor` | `display_name: Text`, `roles: (volunteer\|researcher\|reviewer\|organization_operator)[]` (nonempty), `languages: language-tag[]` (nonempty) |
| `contribution` | `contribution_type: COMMENT\|CORRECTION\|TRANSLATION\|GEOLOCATION\|EARLIER_COPY\|SOURCE_CITATION\|CHALLENGE`, `contributor_id: ID(contributor)`, `target: EvidenceRef`, `body: Text`, `language: language-tag`, `english_rendering: Text?`, `public_display: pseudonym\|anonymous`, `submitted_at: UTC`, `evidence_source_ids: ID(source)[]`, `evidence_claim_ids: ID(claim)[]`, `evidence_media_ids: ID(media)[]`, `proposed_location_id: ID(location)?`, `proposal_basis: Text?`, `translation_of: EvidenceRef?`, `translation_method: human\|machine\|null`, `translation_review: Review?` |
| `vote` | `contributor_id: ID(contributor)`, `contribution_id: ID(contribution)`, `value: HELPFUL\|NOT_HELPFUL`, `voted_at: UTC` |
| `task` | `task_type: GEOLOCATE\|TRANSLATE\|FIND_EARLIER_COPY\|SOURCE_OR_CHALLENGE`, `title: Text`, `target: EvidenceRef`, `creator_id: ID(contributor)`, `assignee_id: ID(contributor)?`, `state: OPEN\|IN_PROGRESS\|SUBMITTED\|REVIEWED`, `created_at: UTC`, `updated_at: UTC`, `submission_contribution_ids: ID(contribution)[]`, `review: Review?` |
| `subscription` | `contributor_id: ID(contributor)`, `subject: Ref` (person/location/media/incident/organization), `created_at: UTC`, `delivery: "in_app"`, `active: boolean`, `event_types: (new_claim\|status_change\|location_change\|source_correction\|media_evidence\|task_update)[]` (nonempty) |
| `investigation` | `owner_id: ID(contributor)`, `investigation_type: PERSON_TIMELINE\|ACCESS_HAZARD\|AID_FACILITY\|MEDIA_LINEAGE`, `title: Text`, `query: Text`, `subject_refs: SubjectRef[]`, `selected_source_ids: ID(source)[]` (nonempty), `selected_claim_ids: ID(claim)[]` (nonempty), `gaps: Text[]`, `time_cutoff: UTC`, `saved_at: UTC` |

Unknown age is null; zero denotes an infant. Organization/facility names visibly
include Exercise or Demo. Contributor roles do not certify institutional identity.
Person support-needs references must concern that same Person; descriptive
attributes originate in cited reports and do not establish a canonical identity.

### Claims, publications and immutable evidence

`SourceDependency` is `{source_id, relationship: relays|cites|corrects|translation_of}`.
`Provenance` is `{extraction_method: "fixture_authored", original_excerpt: Text,
source_locator: Text?}`. Authored normalized fixtures are not proof an extraction
model ran. A later importer records its actual extraction/parsing method and
real ingestion time separately, retaining the original catalog provenance.
`Assertion` is `{type, text: Text, quantity: nonnegative number?, unit: enum?,
related_subjects: SubjectRef[]}`. Quantity and unit are both null or both present.
Units: `people|beds|households|litres|kg|meals|kits|vehicles|metres|hours|items`.

| Claim subject | Allowed `assertion.type` |
| --- | --- |
| person | MISSING, FOUND_SAFE, INJURED, DECEASED, SEEN_AT_LOCATION, PERSON_DETAIL |
| infrastructure | ACCESS_BLOCKED, ACCESS_OPEN, ACCESS_RESTRICTED, INSPECTION_REQUIRED, INSPECTION_REPORTED, OUTAGE_REPORTED, SERVICE_RESTORED |
| hazard | HAZARD_REPORTED, HAZARD_RECEDING, HAZARD_LOCATION, CAUSE_UNCERTAIN |
| aid | AID_NEEDED, AID_OFFERED, AID_DISPATCHED, AID_DELIVERED |
| facility | FACILITY_OPEN, FACILITY_CLOSED, FACILITY_CAPACITY, FACILITY_OCCUPANCY, FACILITY_SERVICE |
| media | CAPTURE_TIME_CLAIM, CAPTURE_LOCATION_CLAIM, CAPTION_CONTEXT_CLAIM, COPY_ATTRIBUTION |
| organization | ORG_SERVICE_AVAILABLE, ORG_CONTACT_POINT, ORG_BULLETIN_CORRECTION |

Claims have exactly one Source and one subject; a Source has 1/2/4/5 claims in
the primary quota histogram. Publisher is exactly one typed Organization OR
Contributor reference. Organization source_type matches its organization_type;
contributor publications use INDIVIDUAL or COMMUNITY_NEWS. Declared dependencies
require nonempty dependencies; no_dependency_declared/unknown use an empty array. All claims from a Source and that Source have identical
`available_at`; related Media needed by those claims are released in that batch
or earlier. `published_at` and known report time may precede availability; future
forecast assertions are outside this corpus. No declared dependency does not establish independence; the independent-source quota is an oracle design check. Source reference uniqueness is
`(incident_id, publisher.kind, publisher.id, report_reference)`. An identical
retry preserves IDs; changed content requires new Source/Claim IDs and correction
links. Original excerpts must be present in the immutable raw source content.
Corrections and source dependencies form DAGs; never self-reference. Caption and
capture-time claims remain claims, even when their technical metadata disagrees.

### Geography and actual assets

`Geometry` is RFC 7946 Point, Polygon or MultiPolygon, two-dimensional WGS84
`[longitude, latitude]`; schema bounds are longitude ±180, latitude ±90.
Rings close and have at least four positions; topology, holes and geographic
membership require semantic validation. `(0,0)` is forbidden. Approximate/site
points require a positive uncertainty radius; areas require null radius and
Polygon/MultiPolygon. No location record is created for an unknown place.
`AdminRef` is `{level: province|district|municipality|ward|other, code: Text?,
name: Text, boundary_reference: Text, boundary_epoch: date?}`.
`LocationProvenance` is `{basis: Text, historical_reference_ids: hist-ID[],
context_feature_ids: Text[], terrain_validation: validated|not_available|not_applicable}`.
Coordinate method and provenance must describe real sampling/anchor work; at
least one contextual feature/reference is required. Catalog role and precision
must agree. Never manufacture coordinates to meet a quota; block generation if
verified anchors/approved sampling zones are unavailable. Five decimal places
maximum for sampled points does not imply that accuracy.

Asset paths are project-relative under `demo/assets/bhotekoshi-2016-exercise-v1/`:
`images/<media-id>.jpg|jpeg|png|webp`, optional `videos/<media-id>.mp4`, optional
`frames/<media-id>.jpg|jpeg|png|webp`, and `thumbnails/<media-id>.webp`. No absolute
paths, traversal, URLs or undeclared extra files. File stem must equal Media ID.
Hashes are lowercase 64-hex SHA-256 of actual bytes; sizes/dimensions/MIME are
measured. Actual creation time is the generation/staging operation time, not
filesystem mtime after copying and not a fictional 2016 capture time.
`embedded_metadata_is_synthetic=true` warns that any embedded fixture metadata
was deliberately controlled; it does not assert metadata exists. Read EXIF from
bytes during a real check. `FrameOrigin` is `{video_media_id, offset_seconds}`;
frames require it and a valid source video, while images/videos have null origin.
File/thumbnail stems equal the media ID, and raw-report stems equal the Source ID.
Optional video/frame records reuse existing primary Sources; they add no Sources
to primary quotas. Primary claims must not reference optional Media, so omitting
the pack cannot break base foreign-key closure. Only videos have duration; frame offset is strictly below duration. Declared
predecessor links are allowed only when the publication explicitly discloses
them. Undisclosed family membership belongs only in the oracle.

## Cross-record and replay invariants

- All references resolve by kind and incident, except the single explicit
  add_control_share reset-test relationship; that exception never moves claims.
  Incident self-reference is the
  only allowed self-reference. No edge may expose a record before its release.
  Same-batch mutual references are allowed only where the relation is not a DAG.
  Allocate all nodes/ID mappings first, then link and validate the release batch;
  Person support-needs claims and their subjects may reference each other.
  Earlier-copy-arrives-last cases omit undisclosed predecessor links until real
  discovery; future source content cannot leak through dependency closure.
- At T+12 baseline, all 1,150 Person records and initial MISSING claims exist.
  Future hospital reports, reviews and results do not. Load profiles contain
  immutable catalog records with foreign-key closure; apply the time filter too.
- Runtime `ingested_at`, `jid()` mappings, candidates, signals, summaries, alerts,
  exports and activity are created by real operations. No such catalog kinds
  exist. Unavailable features leave replay actions blocked with a reason.
- Contribution translation fields exist only for translations; geolocation
  proposal fields only for GEOLOCATION. Proposed locations carry uncertainty.
  EARLIER_COPY/SOURCE_CITATION require cited sources/media; CHALLENGE/CORRECTION
  require a precise target and reason. Claims must cite new corrective sources.
- Vote uniqueness is `(contributor_id, contribution_id)`; no self-votes. Public
  anonymity hides display identity while the server retains contributor ID.
- Catalog tasks are immutable fictional workflow snapshots as of release, not
  evidence that live task actions executed. available_at is no earlier than
  every included workflow timestamp: task creation/update/review, contribution
  submission/translation review, vote time, subscription creation, investigation
  saved time. Future transitions require a separate versioned-event extension;
  this v1 replay format does not prescribe advance_task.
- OPEN tasks have no assignee/submission/review; IN_PROGRESS requires assignee;
  SUBMITTED and REVIEWED require linked contributions and assignee; REVIEWED
  requires reviewer/time/evidence. Review cannot predate submission. Task state
  is reported workflow state, not correctness. No vote or task edits a status.
- Subscription uniqueness is `(contributor_id, subject.kind, subject.id)`; no
  email/SMS dispatch. Alert idempotency is subscription + trigger event + kind.
- Investigation selections were available by `time_cutoff`, which is no later
  than saved time. A saved question can admit insufficient evidence.
- No quantities are compared across different units. Capacity/occupancy claims
  have quantity+unit; overcapacity requires explicit reported overcrowding.
- Current runtime source sharing, typed subjects, MediaCopy, community and full
  subscriptions need adapters. Create edges from these stored references; do not
  generate a second arbitrary edge table. Reject/defer unsupported semantics.

## Supporting file contracts (closed shapes)

These are specifications for later files, not data created by this change.
Support objects reject undocumented keys. `hist/lic/gid/pair/fam/scn/action/query/
case/check` IDs use their literal prefix plus six digits. Support UTC values
use the same syntax; actual generation/retrieval times are distinct from replay.
Arrays contain unique IDs unless an ordered action sequence intentionally retries
an action. All paths are project-relative; file integrity checks reject symlinks
escaping approved roots. Support files and oracles are never served to clients. Manifest schema_path and
quota_path are `demo/spec/trace-record.schema.json` and `demo/spec/quotas.json`.
Its file inventory excludes the manifest itself and validation-report.json,
avoiding recursive hashes; the report records the manifest hash as check evidence.

| File / record | Exact shape and semantics |
| --- | --- |
| `manifest.json` | `{schema_version, dataset_id, seed: integer, sampler: Sampler, generated_at: UTC, generator: {name, version}, asset_tools: [{name, version}], scenario_clock_start: UTC, schema_path, quota_path, files: [{path, sha256, byte_size, role}], profiles: [{name: full\|hero\|control\|video, record_ids: ID[], asset_media_ids: ID(media)[], counts_by_kind: object with all 17 nonnegative-integer kind keys, closure_checked: boolean}], deviations: Text[], limitations: Text[]}`. `role` is catalog/raw/context/license/oracle/replay/query/invalid/asset/thumbnail/control. Actual checksums, not promises. |
| `raw/reports/<source-id>.json` | `{schema_version: "1.0", source_id, report_reference, publisher: PublisherRef, original_language, published_time_text: Text?, original_content: Text, entries: [{subject_label: Text, assertion_text: Text, reported_time_text: Text?, location_text: Text?}]}`. Entry count equals normalized claim count. This CGX-style fixture envelope is not an existing API. `Provenance.original_excerpt` is a verbatim substring of original_content; source_locator identifies an entry. |
| `raw/reports/<source-id>.txt` | Nonempty UTF-8 original publication text, preserved byte-for-byte; includes all claim excerpts. No JSON wrapper or invented actual organization URLs. |
| `context/historical-references.jsonl` | `{id: hist-ID, url, title, publisher, publication_date: date, retrieval_date: date, supported_statement, passage_or_figure, event_time: Time, scope_and_uncertainty}`. Factual context only; no fictional persons/reports. |
| `context/geography.geojson` | RFC 7946 FeatureCollection. Each Feature has `id`, valid Point/LineString/MultiLineString/Polygon/MultiPolygon geometry, and exact properties `{label: Text, feature_type: settlement\|river\|road\|administrative\|sampling_zone, historical_reference_ids: hist-ID[], source_url: URL, source_feature_id: Text, source_version: Text, source_license: Text, source_license_url: URL?, use_conditions: Text, source_artifact_path: path, source_artifact_sha256: SHA256, country_codes: ISO-alpha-2[], coordinate_precision_m: nonnegative number?, retrieved_at: UTC, geometry_epoch: date?, uncertainty_m: nonnegative number?, limitations: Text}`. Feature id is stable `geo-<six digits>`; sort by id. Current geometry epoch is explicit. Source artifact checksum is measured from the preserved upstream input file, not this FeatureCollection (avoids recursive hashes). |
| `licenses.json` | `{dataset_id, assets: [{license_id: lic-ID, media_id, origin: generated\|self_staged\|derived, tool: {name, version}, actual_created_at: UTC, usage_basis: Text, attribution: Text, source_reference: Text?, artifact_sha256: SHA256, limitations: Text[]}]}`. One entry per Media file; never invent a license. Private generation/transformation recipes belong in oracle, not captions. |
| `oracle/identities.jsonl` | `{id: gid-ID, person_ids: ID(person)[], canonical_age: integer 0..90?, primary_person_id, initial_location_id: ID(location)?, initial_precision: point\|area\|unknown, initial_cluster: kodari_tatopani\|inhabited_intermediate_corridor\|bahrabise\|lamosanghu_khadichaur\|sparse_accessible_corridor\|null}`. Non-point cluster is null; primary record is evaluator-only. Every public Person appears exactly once; multiplicity 1/2/3 matches quotas. |
| `oracle/identity-pairs.jsonl` | `{id: pair-ID, person_a_id, person_b_id, same_individual: boolean, evidence_claim_ids: ID(claim)[], rationale: Text, tags: Text[]}`. Pair IDs are unordered-unique; all 165 true pairs +85 hard negatives. Neither this set nor labels are resolver input. |
| `oracle/media-families.jsonl` | `{id: fam-ID, base_media_id, family_class: base_plus_exact_copy\|base_plus_resize\|base_plus_reencode\|base_plus_crop\|singleton, content_category, base_metadata: controlled_gps_exif\|non_gps_exif\|no_exif, members: [{media_id, parent_media_id: ID(media)?, operation: base\|byte_copy\|resize\|reencode\|crop, parameters: TransformParameters}], unrelated_lookalike_family_ids: fam-ID[], tags: Text[]}`. Content categories match quotas; base parent is null, all others reference base. Lookalike links symmetric. |
| `oracle/checkpoints.jsonl` | `{id: check-ID, hours_from_start: 0\|6\|12\|24\|36\|48\|72, at: UTC, identity_summaries: [{identity_id: gid-ID, summary: NOT_YET_REPORTED\|MISSING\|FOUND_SAFE\|INJURED\|UNRESOLVED, supporting_claim_ids: ID(claim)[]}], summary_counts: {NOT_YET_REPORTED, MISSING, FOUND_SAFE, INJURED, UNRESOLVED}, required_assertions: ExpectedAssertion[]}`. All 1,000 identities listed at each cutoff, including not-yet-reported; totals recompute from visible-at-cutoff claims plus private identity grouping. |
| `replay/scenarios.jsonl` | `{id: scn-ID, title, purpose, tabs: (Map\|People\|Media\|Organizations\|Graph)[], focal_refs: EvidenceRef[], action_ids: action-ID[], required_capabilities: Text[], expected_assertions: ExpectedAssertion[]}`. At least three distinct tabs; IDs refer to this catalog. |
| `replay/actions.jsonl` | `{id: action-ID, scenario_ids: scn-ID[], at: UTC, actor_id: ID(contributor)?, operation: enum below, payload: operation-specific object, requires_capabilities: Text[], after_action_ids: action-ID[], expected_assertions: ExpectedAssertion[]}`. Dependency DAG; sequential order within equal time is ID order after dependencies. This is a plan, never a successful trace. |
| `queries.jsonl` | `{id: query-ID, query_type: PERSON_CHANGE\|GEOGRAPHIC_ACCESS\|AID_FACILITY\|MEDIA_LINEAGE\|INSUFFICIENT_EVIDENCE, question, at: UTC, required_claim_ids: ID(claim)[], required_source_ids: ID(source)[], acceptable_uncertainty: Text[], forbidden_conclusions: Text[]}`. No free-text answer is supplied to the application. |
| `invalid-inputs.jsonl` | `{id: case-ID, category: MALFORMED_MISSING\|BAD_CROSS_INCIDENT_REF\|TIME_SEMANTICS\|MEDIA_PATH_SIZE\|RETRY_INJECTION_UNSUPPORTED, description, input_encoding: json\|utf8\|base64, input: JSON-value, precondition_action_ids: action-ID[], expected_error_class: Text, expected_record_delta: integer, required_capability: Text}`. Use encoded bytes for malformed JSON; source prompt injection is data, never executed instructions. |
| `validation-report.json` | `{dataset_id, generated_at: UTC, tools: [{name, version}], checks: [{rule_id, status: pass\|fail\|blocked, observed: JSON-value, expected: JSON-value, evidence_paths: Text[], limitations: Text[]}], summary: {pass: integer, fail: integer, blocked: integer}}`. Produced from actual checks; implemented runtime gate absent means blocked. |

`Sampler` is exactly `{rng_name: Text, rng_version: Text, algorithm: Text,
algorithm_version: Text, input_order: ID(location)[], zone_quotas:
[{zone_feature_id: Text, point_count: nonnegative integer}], rejection_rules:
Text[], max_attempts_per_point: positive integer, rounding_decimal_places:
integer 0..5, geography_sha256: SHA256}`. The checksum is calculated from the
actual context/geography.geojson bytes. Preserve upstream geographic inputs at
`context/geographic-inputs/` within the dataset directory and inventory their
paths/checksums in the manifest. Exhausted sampling retries block the build;
never silently move a point to an arbitrary fallback or change the quota.

`TransformParameters` is exactly `{width_px: integer?, height_px: integer?,
jpeg_quality: integer 1..100?, crop_box: [left, top, right, bottom]?,
metadata_policy: preserve|strip|controlled_write, embedded_exif: [{tag: Text,
value: JSON-value}], generation_tool: Text?, generation_prompt: Text?}`.
Base/byte copy have null resize/quality/crop fields; byte copy preserves all bytes.
Resize requires width/height; reencode requires quality; crop requires an in-bounds
nonempty integer pixel box. Base generation provenance is retained here. Recipes
are executed, then hash/file metadata recomputed; they are not assumed successful.
`ExpectedAssertion` is exactly `{rule_id: Text, scope_ids: Text[], expectation:
Text, expected_count: integer?, tolerance: number?}`. Expectations specify behavior
and cited records; actual results live only in the validation report/runtime.

| Replay operation | Exact payload |
| --- | --- |
| `release_records` | `{record_ids: ID[]}`; only records with available_at ≤ action time; complete source+claim batch and dependency closure |
| `publish_source` | `{source_id: ID(source), claim_ids: ID(claim)[]}`; invokes real supported publishing/ingestion; repeat unchanged IDs for retry case |
| `review_identity` | `{person_a_id, person_b_id, decision: confirm\|reject, evidence_claim_ids: ID(claim)[], reason: Text}`; actor required; 80 confirmations/20 rejections |
| `run_walker` | `{walker: ResolveWalker\|EvidenceWalker\|WatchWalker, subject_refs: SubjectRef[], quiet: boolean}`; actual supported adapter only; IngestWalker runs through publish_source |
| `submit_contribution` | `{contribution_id: ID(contribution)}`; actor must match contributor |
| `cast_vote` | `{vote_id: ID(vote)}`; actor must match contributor |
| `subscribe` | `{subscription_id: ID(subscription)}`; actor must match contributor |
| `reload_runtime` | `{}`; verify persisted graph with fixture-ID mapping |
| `reset_primary` | `{baseline_hours_from_start: 12}`; preserve controls and shared nodes; restore baseline via actual importer |
| `assert_checkpoint` | `{checkpoint_id: check-ID}`; evaluator only, never returned in API payload |
| `add_control_share` | `{organization_id: ID(organization), incident_id: ID(incident)}`; isolated reset test only; does not move claims across incidents |

Checkpoint identity summaries `(MISSING, FOUND_SAFE, INJURED, UNRESOLVED)` are
T0 `(0,0,0,0)`; T6 `(300,0,0,0)`; T12 `(1000,0,0,0)`; T24 `(850,100,20,30)`;
T36 `(760,160,40,40)`; T48 `(690,210,50,50)`; T72 `(650,250,50,50)`.
`NOT_YET_REPORTED` is the remainder to 1,000. These are hidden expectations,
not display counts or alerts. Sources/claims remain immutable when later activity
arrives. Every runtime replay assertion must be checked against actual results.
