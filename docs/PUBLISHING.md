# Structured publishing and reported-location inspection

Anshu's branch is `codex/anshu`. This slice gives all tabs one real mutation:
review a fictional institutional report, persist its source claim, run WatchWalker,
and refresh the shared graph snapshot. Map pins inspect existing graph evidence.

## Shared additions to coordinate with Miguel

All schema changes are additive and retain existing fields and relationships:

- `Organization(name, organization_type="", is_demo=True)`.
- `HasOrganization: Incident -> Organization`; `Publishes: Organization -> Source`.
- Claim defaults: `incident_id`, `ingested_at`, `original_content`,
  `source_reference`, `extraction_method`, `ingestion_key`, `payload_hash`.
- Alert: `claim_id=""`, used to check whether a subscription received this claim.
- ActivityEntry: `incident_id=""`; new publishing/watch/seed activity is scoped.

One Source represents one report; the Organization is reused. Sources are not
merged merely because their names match. Graph keeps its existing relationships.
`jid()` remains the graph identity; references and hashes are deduplication keys.

## Endpoint and snapshot

`features/organizations/services.jac` exports `publish_report`, registered in
`main.jac`. Named arguments, all strings:

```
incident_id, organization_id, person_id, claim_type,
summary, reported_at, source_reference, original_content
```

Result: `PublishResult(claim_id, duplicate, alerts_created, error="")`.
Validation failures return an actionable `error` with an empty claim ID; the
client must check it before treating a response as success.
Only the named fictional demo incident can be published to through this endpoint.
The selected organization and person must belong to that current incident.
After success, the component calls `await onRefresh()`.

Additive `DashboardSnapshot` fields: `incident_id`, `organizations`.
ClaimView adds source/organization IDs and provenance fields. PersonView adds
`status_summary`; `has_conflict` now means differing latest or undated status
reports need review. A strictly later dated report does not erase earlier history.
Latest status is `UNKNOWN` when unresolved reports disagree.
LocationView adds `id`, `media_ids`, `evidence`, and `basis`. Evidence follows
`Location <- LocatedAt - Media <- SupportedBy - Claim`; no location is inferred
from a person's latest status. Default 0,0, nonfinite, and out-of-range coordinates
are omitted. AlertView adds actual alert and claim IDs.

## Walker compatibility

- IngestWalker keeps its original arguments. `selected_person_id` explicitly
  associates a report; omission creates a new person record for later review.
  There is no name-only merge. New optional arguments: `organization_id`,
  `source_reference`, `original_content`, `extraction_method`.
- An organization/reference pair within an incident is stable. Identical retries
  return the prior claim ID; changed content under that reference is rejected.
  With no reference, internal fixture/import calls use a deterministic hash.
- WatchWalker accepts `incident_id`; it handles several unseen claims in one run,
  distinguishes newer/historical/ambiguous times, and checks per-claim alerts.
- EvidenceWalker only gains optional incident scoping and scoped, explicitly
  simulated trace messages, so demo reset cannot rerun checks on other incidents.
  Aidana still owns its substantive evidence behavior.
- ResolveWalker scoring is unchanged. Its trace now includes the incident ID;
  the dashboard spawns it directly on the current incident. Gabriel owns review.

## Reset and limitations

`demo/reset.jac` collects known records belonging to the named demo. An outside
relationship protects shared nodes and their outgoing descendants. Unrelated
incidents, unknown node types, and legacy unscoped activity are retained. Owners
adding new graph types should extend the reset collector with an isolation test.
Resetting an old starter graph once loads the new institution fixtures.

Reported times use UTC in the form; explicit offsets normalize to UTC. Blank is
unknown. Legacy naive fixture times are interpreted as UTC. Original report text
is kept verbatim; the summary is trimmed. No LLM extraction is claimed.

This is an unauthenticated fictional demo. It is not a verified organization
publishing service. Retry tests are sequential in one runtime; distributed
concurrent publishing/atomic transactions are not claimed. No external messages
are sent. Existing media results remain simulated.

## Verification

Jac native 0.34.1:

```
jac test tests/test_trace.jac tests/test_publishing.jac
jac build --check_only
```

The 13 integration checks cover preserved provenance, invalid inputs, reference
retries/collisions, chronology and unknown times, no name-only merging, stale and
cross-incident IDs, reset isolation (including shared places/evidence), batched
watching, map IDs and coordinate filtering, shared-person incident isolation, and the original scripted demo.

Browser checks: form preview and publish, same-reference retry with zero new
alerts, People/Graph updates, persistence after a server restart, and map source
inspection. Final responsive and repeat-rehearsal results are recorded below.

Deployment: the supplied preview URL redirects to JacHammer sign-in in a fresh
browser session. Public access, hosted mutations, and another physical device
have not been verified. Local preview remains the tested fallback.

Responsive rehearsal: at 390 × 844, the form/preview/publish/retry workflow
completed with no document-level horizontal overflow. Two reset/publish runs
produced one alert each; repeated publishing and WatchWalker produced zero new
alerts. Both map pins opened their own evidence, and viewport/selection survived
tab switching. This is browser viewport emulation, not a second physical device.
