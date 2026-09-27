# People — Gabriel

Entry component: `PeopleTab.jac`.

Own case search, report timelines, human identity review, and walkers/resolve.jac. Add corrections as sourced claims; never overwrite source history.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.

## Identity review flow

Agent proposes a pair -> it appears as a candidate in People -> a human opens
"Review match", sees both records, their claims and sources (agent-cited claims
highlighted), similarities / differences / unknowns -> confirms or rejects with
name + reason -> decision persists and shows after refresh.

Files: `IdentityReview.jac` (UI), `services.jac` (endpoints),
`test_identity_review.jac` (9 tests). Logic: `walkers/resolve.jac`.

### Agent interface (for Anshu / the investigation agent)

`POST /function/propose_identity`

```
propose_identity(incident_name: str, person_a_id: str, person_b_id: str,
                 proposed_by: str, rationale: str, cited_claim_ids: list[str])
  -> IdentityDecisionResult {ok, message, changed, decision, pair_key}
```

- IDs are Person `jid`s from `DashboardSnapshot.people[].id`; claim IDs from
  `people[].claims[].id`. Order of the two person IDs does not matter.
- Refused (ok=False, nothing written): unknown incident, same ID twice, an ID
  that is not a Person in that incident, a cited ID that is not a claim about
  one of the two records, empty `proposed_by`.
- Idempotent per pair: same proposal again returns changed=False; a new
  rationale/citation set updates the one proposal in place.
- A proposal never creates a decision or association. After calling it,
  the agent (or the shell) should `await onRefresh()`.

`POST /function/review_identity` (called by the panel)

```
review_identity(incident_name, person_a_id, person_b_id, decision, reviewer,
                note, basis: list[str], evidence_claim_ids: list[str])
```

Same validation, plus decision in {CONFIRMED, REJECTED} and non-empty reviewer.

### Integrated shared changes
- **Miguel (schema, graph/nodes.jac + graph/edges.jac):**
  - `IdentityDecision` (one per pair, `pair_key` = sorted jids) gained
    `incident_name`, `evidence_claim_ids`, `past_reviews: list[IdentityReviewEntry]`.
    The legacy `history: list[str]` field is kept but no longer written.
  - New `obj IdentityReviewEntry {decision, reviewer, decided_at, note, basis, evidence_claim_ids}`.
  - New `node IdentityProposal {pair_key, person_a_id, person_b_id, incident_name,
    proposed_by, rationale, cited_claim_ids, proposed_at}` attached to root.
  - `edge Reviews: IdentityDecision --> Person` (unchanged from v1).
- **Anshu (integration):**
  - `main.jac` imports `features.people.services { review_identity, propose_identity, IdentityDecisionResult }`.
  - `DuplicateCandidate` (in the snapshot) gained defaulted fields: incident_name,
    evidence_claim_ids, past_reviews, proposed_by, proposal_rationale,
    cited_claim_ids, differences, unknowns. No renames.
  - ResolveWalker now also lists agent-proposed pairs that the name/age rules
    did not flag (label "NOT RULE-MATCHED").
  - IngestWalker associates reports only through an explicit person ID; otherwise
    it creates a separate record. Review decisions do not silently redirect ingestion.

### Behaviour notes
- "Latest status" comparisons sort status claims by report timestamp and keep
  repeats, so MISSING -> FOUND_SAFE -> MISSING ends at MISSING. Undated claims
  are not ordered and are reported as "No dated status report".
- Unknowns only say what the graph does not hold ("No ... comparison result is
  recorded"); they never claim a check was or was not performed.

### Limitations
- Reviewer is a typed name (no auth).
- A CONFIRMED decision does not merge timelines or change displayed status.
- Incident-scoped reset clears its decisions/proposals while preserving shared and unrelated data.
- PersonView flags differing latest/undated status reports for review; it does not
  treat strictly earlier differing reports as a current conflict.
