"""ResolveWalker: find people who MIGHT be the same person.

It compares every pair of people in an incident using simple, explainable
rules (name similarity + age). It NEVER merges anyone - it only reports
candidates so a human can confirm later.

Human review: f"record_identity_decision" stores ONE IdentityDecision per
pair of Person records (keyed by their sorted jids). Both Person nodes and
all their claims are left untouched; the decision only points at them.
Repeating the same decision changes nothing; a changed decision keeps the
earlier one in the decision's history.

FUTURE: AI-assisted identity resolution (by llm) can replace f"score_pair",
but its output must stay a "candidate", never an automatic merge.
"""

import from graph.nodes { Incident, Person, IdentityDecision }
import from graph.edges { Involves, Reviews }
import from graph.activity { log_activity, now_iso }

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
        decision: str = "PENDING",
        reviewer: str = "",
        decided_at: str = "",
        note: str = "",
        history: list[str] = [];
}

# Result of a review request, so the UI can show exactly what happened.
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
        confidence=confidence, reasons=reasons
    );
    attach_decision(cand);
    return cand;
}

# Copy any persisted human decision onto the in-memory candidate.
def attach_decision(cand: DuplicateCandidate) -> None {
    cand.pair_key = pair_key_for(cand.person_a_id, cand.person_b_id);
    d = find_decision(cand.pair_key);
    if d {
        cand.decision = d.decision;
        cand.reviewer = d.reviewer;
        cand.decided_at = d.decided_at;
        cand.note = d.note;
        cand.history = list(d.history);
    }
}

# Record a human CONFIRMED / REJECTED decision about two Person records.
# Never merges, deletes, or edits either Person or any Claim.
def record_identity_decision(
    person_a_id: str,
    person_b_id: str,
    decision: str,
    reviewer: str,
    note: str = "",
    basis: list[str] = []
) -> IdentityDecisionResult {
    decision = decision.strip().upper();
    reviewer = reviewer.strip();
    if decision not in DECISIONS {
        return IdentityDecisionResult(ok=False, message="Decision must be CONFIRMED or REJECTED.");
    }
    if not reviewer {
        return IdentityDecisionResult(ok=False, message="Enter the reviewer's name so the decision is attributed.");
    }
    if person_a_id == person_b_id {
        return IdentityDecisionResult(ok=False, message="A record cannot be compared with itself.");
    }
    a = jobj(person_a_id);
    b = jobj(person_b_id);
    if not isinstance(a, Person) or not isinstance(b, Person) {
        return IdentityDecisionResult(ok=False, message="One of these records no longer exists. Refresh and try again.");
    }
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
        existing.history = existing.history + [
            f"{existing.decision} by {existing.reviewer} at {existing.decided_at}"
        ];
        existing.decision = decision;
        existing.reviewer = reviewer;
        existing.decided_at = when;
        existing.note = note.strip();
        existing.basis = basis;
    } else {
        rec = IdentityDecision(
            pair_key=key,
            person_a_id=person_a_id, person_b_id=person_b_id,
            person_a_name=a.name, person_b_name=b.name,
            decision=decision, reviewer=reviewer, decided_at=when,
            note=note.strip(), basis=basis
        );
        root ++> rec;
        rec +>:Reviews():+> a;
        rec +>:Reviews():+> b;
    }
    log_activity(
        "ResolveWalker",
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

    # Inside an incident: compare each pair of people once.
    can compare_people with Incident entry {
        people = [here ->:Involves:->];
        for i in range(len(people)) {
            for j in range(i + 1, len(people)) {
                match_ = score_pair(people[i], people[j], here.name);
                if match_ {
                    self.candidates.append(match_);
                }
            }
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
