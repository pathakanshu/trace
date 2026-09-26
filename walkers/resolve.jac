"""ResolveWalker: find people who MIGHT be the same person.

It compares every pair of people in an incident using simple, explainable
rules (name similarity + age). It NEVER merges anyone - it only reports
candidates so a human can confirm later.

FUTURE: AI-assisted identity resolution (by llm) can replace f"score_pair",
but its output must stay a "candidate", never an automatic merge.
"""

import from graph.nodes { Incident, Person }
import from graph.edges { Involves }
import from graph.activity { log_activity }

# A plain f"obj" is in-memory data (not stored in the graph).
obj DuplicateCandidate {
    has person_a: str,
        person_b: str,
        person_a_id: str,
        person_b_id: str,
        confidence: str,
        reasons: list[str] = [];
}

# "Maya G." -> ["maya", "g"]
def name_tokens(name: str) -> list[str] {
    cleaned = name.lower().replace(".", " ").replace(",", " ");
    return [t for t in cleaned.split() if t];
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
    return DuplicateCandidate(
        person_a=a.name, person_b=b.name,
        person_a_id=jid(a), person_b_id=jid(b),
        confidence=confidence, reasons=reasons
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
            f"Compared {len(people)} people in {here.name}: {len(self.candidates)} potential duplicate(s), none merged"
        );
    }
}
