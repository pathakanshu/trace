"""ResolveWalker: find people who MIGHT be the same person.

It compares every pair of people in an incident using simple, explainable
rules (name similarity + age). It NEVER merges anyone - it only reports
candidates so a human can confirm later.

Human review:
- f"propose_identity_pair" lets an agent put a pair + cited claim ids in front
  of a human (IdentityProposal). A proposal is only a suggestion.
- f"record_identity_decision" stores ONE IdentityDecision per pair of Person
  records (keyed by their sorted jids), validated server-side. Both Person
  nodes and all claims are left untouched. Repeating the same decision
  changes nothing; a changed decision keeps the complete earlier review.
- f"compare_records" builds the similarities / differences / unknowns the
  review panel shows, using claim timestamps (never list order).

FUTURE: AI-assisted identity resolution (by llm) can replace f"score_pair",
but its output must stay a "candidate", never an automatic merge.
"""

import from graph.nodes {
    Incident, Person, Claim, Source, IdentityDecision, IdentityProposal, IdentityReviewEntry
}
import from graph.edges { Involves, Reviews, About, Asserts }
import from graph.activity { log_activity, now_iso }
import from walkers.watch { STATUS_CLAIMS }

glob DECISIONS: list[str] = ["CONFIRMED", "REJECTED"];

# A plain f"obj" is in-memory data (not stored in the graph).
obj DuplicateCandidate {
    has person_a: str,
        person_b: str,
        person_a_id: str,
        person_b_id: str,
        confidence: str,
        reasons: list[str] = [],
        # Human review state, copied from the persisted IdentityDecision.
        pair_key: str = "",
        incident_name: str = "",
        decision: str = "PENDING",
        reviewer: str = "",
        decided_at: str = "",
        note: str = "",
        evidence_claim_ids: list[str] = [],
        history: list[str] = [],
        past_reviews: list[IdentityReviewEntry] = [],
        # Agent proposal (if any), copied from IdentityProposal.
        proposed_by: str = "",
        proposal_rationale: str = "",
        cited_claim_ids: list[str] = [],
        # Comparison shown in the review panel (see compare_records).
        differences: list[str] = [],
        unknowns: list[str] = [];
}

# Result of a review / proposal request, so the UI or agent sees what happened.
obj IdentityDecisionResult {
    has ok: bool,
        message: str,
        changed: bool = False,
        decision: str = "",
        pair_key: str = "";
}

# "Maya G." -> ["maya", "g"]
def name_tokens(name: str) -> list[str] {
    cleaned = name.lower().replace(".", " ").replace(",", " ");
    return [t for t in cleaned.split() if t];
}

# Order-independent key for a pair of Person records.
def pair_key_for(a_id: str, b_id: str) -> str {
    ids = sorted([a_id, b_id]);
    return ids[0] + "|" + ids[1];
}

def find_decision(key: str) -> IdentityDecision | None {
    found = [root -->[?:IdentityDecision, pair_key == key]];
    return found[0] if found else None;
}

def find_proposal(key: str) -> IdentityProposal | None {
    found = [root -->[?:IdentityProposal, pair_key == key]];
    return found[0] if found else None;
}

# ---------- Comparison (timestamp-ordered, honest unknowns) ----------

def claims_of(p: Person) -> list[Claim] {
    return [p <-:About:<-];
}

def claim_ts(c: Claim) -> str {
    return c.timestamp;
}

# The newest STATUS claim by report timestamp. Repeated statuses are kept, so
# MISSING -> FOUND_SAFE -> MISSING correctly ends at MISSING. Claims without a
# timestamp cannot be ordered and are ignored here.
def latest_status_claim(p: Person) -> Claim | None {
    dated = [c for c in claims_of(p) if c.claim_type in STATUS_CLAIMS and c.timestamp];
    if not dated {
        return None;
    }
    dated.sort(key=claim_ts);
    return dated[-1];
}

def source_names(p: Person) -> list[str] {
    out: list[str] = [];
    for c in claims_of(p) {
        for s in [c <-:Asserts:<-] {
            if s.name not in out { out.append(s.name); }
        }
    }
    return out;
}

def compare_differences(a: Person, b: Person) -> list[str] {
    out: list[str] = [];
    if a.name != b.name {
        out.append(f"Recorded names differ: '{a.name}' vs '{b.name}'");
    }
    if a.age > 0 and b.age > 0 and a.age != b.age {
        out.append(f"Ages differ: {a.age} vs {b.age}");
    }
    sa = source_names(a);
    sb = source_names(b);
    if sa and sb and not [s for s in sa if s in sb] {
        out.append("Reported by different sources: " + ", ".join(sa) + " vs " + ", ".join(sb));
    }
    la = latest_status_claim(a);
    lb = latest_status_claim(b);
    if la and lb and la.claim_type != lb.claim_type {
        out.append(
            f"Latest status reports differ (by report time): {la.claim_type} at {la.timestamp} vs {lb.claim_type} at {lb.timestamp}"
        );
    }
    return out;
}

# Only states what the graph does NOT hold. Never claims a check did or did
# not happen, and never claims sources were searched for an alias.
def compare_unknowns(a: Person, b: Person, key: str) -> list[str] {
    out: list[str] = [];
    for p in [a, b] {
        if p.age <= 0 { out.append(f"Age not recorded for '{p.name}'"); }
        if not claims_of(p) { out.append(f"No reports attached to '{p.name}'"); }
        elif not latest_status_claim(p) { out.append(f"No dated status report for '{p.name}'"); }
    }
    out.append("No photo, document, or contact comparison result is recorded for this pair");
    if not find_decision(key) {
        out.append("No human review is recorded yet");
    }
    return out;
}

# Copy persisted review, proposal and comparison onto the in-memory candidate.
def attach_decision(cand: DuplicateCandidate) -> None {
    cand.pair_key = pair_key_for(cand.person_a_id, cand.person_b_id);
    d = find_decision(cand.pair_key);
    if d {
        cand.decision = d.decision;
        cand.reviewer = d.reviewer;
        cand.decided_at = d.decided_at;
        cand.note = d.note;
        cand.evidence_claim_ids = list(d.evidence_claim_ids);
        cand.history = list(d.history);
        cand.past_reviews = list(d.past_reviews);
    }
    p = find_proposal(cand.pair_key);
    if p {
        cand.proposed_by = p.proposed_by;
        cand.proposal_rationale = p.rationale;
        cand.cited_claim_ids = list(p.cited_claim_ids);
    }
    a = jobj(cand.person_a_id);
    b = jobj(cand.person_b_id);
    if isinstance(a, Person) and isinstance(b, Person) {
        cand.differences = compare_differences(a, b);
        cand.unknowns = compare_unknowns(a, b, cand.pair_key);
    }
}

# Compare two people and explain why they might match.
def score_pair(a: Person, b: Person, incident_name: str) -> DuplicateCandidate | None {
    ta = name_tokens(a.name);
    tb = name_tokens(b.name);
    if not ta or not tb {
        return None;
    }
    reasons: list[str] = [];
    points = 0;

    if ta[0] == tb[0] {
        reasons.append("same first name");
        points += 1;
        # "g" is an initial of "gurung"?
        if len(ta) > 1 and len(tb) > 1 and ta[-1][0] == tb[-1][0] {
            reasons.append("last name / initial agree");
            points += 1;
        }
    }
    if a.age > 0 and a.age == b.age {
        reasons.append(f"same age ({a.age})");
        points += 1;
    }
    if points < 2 {
        return None;
    }
    reasons.append(f"same incident ({incident_name})");
    confidence = "HIGH" if points >= 3 else "MEDIUM";
    cand = DuplicateCandidate(
        person_a=a.name, person_b=b.name,
        person_a_id=jid(a), person_b_id=jid(b),
        confidence=confidence, reasons=reasons, incident_name=incident_name
    );
    attach_decision(cand);
    return cand;
}

# ---------- Validation shared by proposals and decisions ----------

obj PairCheck {
    has error: str = "",
        a: Person | None = None,
        b: Person | None = None;
}

# Both ids must be Person records, different, and both involved in the named incident.
def check_pair(person_a_id: str, person_b_id: str, incident_name: str) -> PairCheck {
    if not person_a_id or not person_b_id {
        return PairCheck(error="Both record ids are required.");
    }
    if person_a_id == person_b_id {
        return PairCheck(error="A record cannot be compared with itself.");
    }
    incidents = [root -->[?:Incident, name == incident_name]];
    if not incidents {
        return PairCheck(error=f"Incident '{incident_name}' was not found.");
    }
    members = [p for p in [incidents[0] ->:Involves:->]];
    a: Person | None = None;
    b: Person | None = None;
    for p in members {
        if jid(p) == person_a_id { a = p; }
        if jid(p) == person_b_id { b = p; }
    }
    if a is None or b is None {
        return PairCheck(error=f"Both records must be people in incident '{incident_name}'. Refresh and try again.");
    }
    return PairCheck(a=a, b=b);
}

# Keep only ids that resolve to Claims about one of the two records.
def valid_claim_ids(ids: list[str], a: Person, b: Person) -> list[str] {
    allowed = [jid(c) for c in claims_of(a)] + [jid(c) for c in claims_of(b)];
    out: list[str] = [];
    for cid in ids {
        if cid in allowed and cid not in out { out.append(cid); }
    }
    return out;
}

# ---------- Agent -> review panel ----------

# An agent proposes that two records in an incident may be the same person,
# citing claim ids. Validated like a decision. Idempotent per pair.
def propose_identity_pair(
    incident_name: str,
    person_a_id: str,
    person_b_id: str,
    proposed_by: str,
    rationale: str = "",
    cited_claim_ids: list[str] = []
) -> IdentityDecisionResult {
    proposed_by = proposed_by.strip();
    if not proposed_by {
        return IdentityDecisionResult(ok=False, message="proposed_by is required (which agent or person proposed this).");
    }
    chk = check_pair(person_a_id, person_b_id, incident_name);
    if chk.error or chk.a is None or chk.b is None {
        return IdentityDecisionResult(ok=False, message=chk.error);
    }
    cited = valid_claim_ids(cited_claim_ids, chk.a, chk.b);
    if len(cited) != len(set(cited_claim_ids)) {
        return IdentityDecisionResult(ok=False, message="Every cited claim id must be a report about one of these two records.");
    }
    key = pair_key_for(person_a_id, person_b_id);
    existing = find_proposal(key);
    if existing and existing.proposed_by == proposed_by and existing.rationale == rationale.strip()
        and sorted(existing.cited_claim_ids) == sorted(cited) {
        return IdentityDecisionResult(ok=True, changed=False, pair_key=key, message="Proposal already recorded. Nothing was changed.");
    }
    if existing {
        existing.proposed_by = proposed_by;
        existing.rationale = rationale.strip();
        existing.cited_claim_ids = cited;
        existing.proposed_at = now_iso();
    } else {
        root ++> IdentityProposal(
            pair_key=key, person_a_id=person_a_id, person_b_id=person_b_id,
            incident_name=incident_name, proposed_by=proposed_by,
            rationale=rationale.strip(), cited_claim_ids=cited, proposed_at=now_iso()
        );
    }
    log_activity(
        proposed_by,
        f"Proposed that '{chk.a.name}' and '{chk.b.name}' may be the same person, citing {len(cited)} report(s). Waiting for human review."
    );
    return IdentityDecisionResult(ok=True, changed=True, pair_key=key, message="Proposal sent to human review.");
}

# ---------- Human decision ----------

# Record a human CONFIRMED / REJECTED decision about two Person records.
# Never merges, deletes, or edits either Person or any Claim.
def record_identity_decision(
    incident_name: str,
    person_a_id: str,
    person_b_id: str,
    decision: str,
    reviewer: str,
    note: str = "",
    basis: list[str] = [],
    evidence_claim_ids: list[str] = []
) -> IdentityDecisionResult {
    decision = decision.strip().upper();
    reviewer = reviewer.strip();
    note = note.strip();
    if decision not in DECISIONS {
        return IdentityDecisionResult(ok=False, message="Decision must be CONFIRMED or REJECTED.");
    }
    if not reviewer {
        return IdentityDecisionResult(ok=False, message="Enter the reviewer's name so the decision is attributed.");
    }
    chk = check_pair(person_a_id, person_b_id, incident_name);
    if chk.error or chk.a is None or chk.b is None {
        return IdentityDecisionResult(ok=False, message=chk.error);
    }
    a = chk.a;
    b = chk.b;
    evidence = valid_claim_ids(evidence_claim_ids, a, b);
    key = pair_key_for(person_a_id, person_b_id);
    existing = find_decision(key);

    if existing and existing.decision == decision {
        return IdentityDecisionResult(
            ok=True, changed=False, decision=decision, pair_key=key,
            message=f"Already {decision.lower()} by {existing.reviewer} at {existing.decided_at}. Nothing was changed."
        );
    }

    when = now_iso();
    if existing {
        # Keep the complete earlier review, not just who and when.
        existing.past_reviews = existing.past_reviews + [IdentityReviewEntry(
            decision=existing.decision, reviewer=existing.reviewer,
            decided_at=existing.decided_at, note=existing.note,
            basis=list(existing.basis), evidence_claim_ids=list(existing.evidence_claim_ids)
        )];
        existing.decision = decision;
        existing.reviewer = reviewer;
        existing.decided_at = when;
        existing.note = note;
        existing.basis = basis;
        existing.evidence_claim_ids = evidence;
    } else {
        rec = IdentityDecision(
            pair_key=key,
            person_a_id=person_a_id, person_b_id=person_b_id,
            person_a_name=a.name, person_b_name=b.name,
            incident_name=incident_name,
            decision=decision, reviewer=reviewer, decided_at=when,
            note=note, basis=basis, evidence_claim_ids=evidence
        );
        root ++> rec;
        rec +>:Reviews():+> a;
        rec +>:Reviews():+> b;
    }
    log_activity(
        "Human review",
        f"{reviewer} {decision.lower()} that '{a.name}' and '{b.name}' may be the same person. Both records and their reports were kept."
    );
    return IdentityDecisionResult(
        ok=True, changed=True, decision=decision, pair_key=key,
        message=f"Saved: {decision.lower()} by {reviewer}. Both original records were kept."
    );
}

walker ResolveWalker {
    has candidates: list[DuplicateCandidate] = [],
        # quiet=True skips the activity log (used when the dashboard refreshes).
        quiet: bool = False;

    # Start at root and walk into every Incident.
    can start with Root entry {
        visit [root -->[?:Incident]];
    }

    # Inside an incident: compare each pair of people once. Agent proposals
    # for pairs the rules did not flag are added too, so they reach review.
    can compare_people with Incident entry {
        people = [here ->:Involves:->];
        seen: list[str] = [];
        for i in range(len(people)) {
            for j in range(i + 1, len(people)) {
                match_ = score_pair(people[i], people[j], here.name);
                if match_ {
                    self.candidates.append(match_);
                    seen.append(match_.pair_key);
                }
            }
        }
        for prop in [root -->[?:IdentityProposal, incident_name == here.name]] {
            if prop.pair_key in seen { continue; }
            a = jobj(prop.person_a_id);
            b = jobj(prop.person_b_id);
            if not isinstance(a, Person) or not isinstance(b, Person) { continue; }
            cand = DuplicateCandidate(
                person_a=a.name, person_b=b.name,
                person_a_id=prop.person_a_id, person_b_id=prop.person_b_id,
                confidence="NOT RULE-MATCHED", reasons=[], incident_name=here.name
            );
            attach_decision(cand);
            self.candidates.append(cand);
        }
        if self.quiet {
            skip;
        }
        log_activity(
            "ResolveWalker",
            f"Looked for records that may be the same person: found {len(self.candidates)} possible match(es). Nothing was combined; a person must confirm."
        );
    }
}
