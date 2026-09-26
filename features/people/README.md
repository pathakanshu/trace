# People — Gabriel

Entry component: `PeopleTab.jac`.

Own case search, report timelines, human identity review, and walkers/resolve.jac. Add corrections as sourced claims; never overwrite source history.

Keep feature components, helpers, new server adapters, and focused tests in this folder.
All tabs receive a read-only `DashboardSnapshot` and async `onRefresh` callback.
After a successful server write, `await onRefresh()` to update all views.

See [the team contract](../../docs/TEAM.md) before changing shared interfaces.

## Human identity review (first deliverable)

Flow: People tab -> candidate card "Review match" -> side-by-side records with their
claims and sources, rule-based similarities, observable differences, unknowns ->
reviewer name + optional reason -> Confirm / Reject -> `await onRefresh()`.

Files: `IdentityReview.jac` (UI), `services.jac` (`review_identity` endpoint),
`test_identity_review.jac` (5 tests). Logic: `walkers/resolve.jac::record_identity_decision`.

### Shared changes needing sign-off
- **Miguel (schema):** `node IdentityDecision` (graph/nodes.jac) and
  `edge Reviews: IdentityDecision --> Person` (graph/edges.jac). One node per pair
  (`pair_key` = sorted Person jids), attached to root, pointing at both Person
  records. Fields: decision (CONFIRMED|REJECTED), reviewer, decided_at, note, basis,
  history. Person/Claim nodes are never merged or edited.
- **Anshu (integration):** `main.jac` imports
  `features.people.services { review_identity, IdentityDecisionResult }`.
  Signature: `review_identity(person_a_id: str, person_b_id: str, decision: str,
  reviewer: str, note: str, basis: list[str]) -> IdentityDecisionResult`.
  `DuplicateCandidate` (already in the snapshot) gained defaulted fields:
  pair_key, decision, reviewer, decided_at, note, history. No renames.
- **Anshu (ingestion flag):** `IngestWalker.find_or_create_person` matches people
  by exact name only. Two different people with the same name would be silently
  combined, and a confirmed review is NOT consulted by ingestion. This needs a
  stronger identity key or a review step before general publishing.

### Limitations
- Reviewer is a typed name (no auth); anyone can record a decision.
- A CONFIRMED decision does not change timelines or status; records stay separate.
- `reset_demo` still uses the broad graph wipe, which also clears decisions.
