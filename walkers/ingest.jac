"""IngestWalker: turn one structured report into graph nodes.

Flow:   demo input  ->  IngestWalker  ->  Source -Asserts-> Claim -About-> Person
                                          Incident -Involves-> Person

JAC 101: a f"walker" is code that MOVES through the graph. You "spawn" it on a
node (f"root spawn IngestWalker(...)"), and it runs the f"can ... with X entry"
ability matching each node type it lands on. f"visit" queues the next node(s).

FUTURE: live ingestion (police sites, hospital lists, NGO APIs) should just
build one of these IngestWalker calls per record. Scrape/normalize elsewhere,
then hand clean fields to this walker so provenance is always preserved.
"""

import from graph.nodes { Incident, Person, Claim, Source }
import from graph.edges { Involves, Asserts, About }
import from graph.activity { log_activity, plain_status }

walker IngestWalker {
    # Input fields (one report). These are the walker's "arguments".
    # (Required fields first, then fields with defaults - Jac requires this order.)
    has incident_name: str,
        person_name: str,
        source_name: str,
        claim_type: str,
        person_age: int = 0,
        source_type: str = "",
        claim_value: str = "",
        timestamp: str = "",
        notes: str = "";

    # Output: filled in while walking, read by whoever spawned us.
    has created_claim_id: str = "",
        person_id: str = "";

    # Step 1 - at root: find the incident (or create it) and walk into it.
    can find_incident with Root entry {
        # f"[root -->[?:Incident, name == ...]]" = "nodes connected to root that
        # are Incidents with this name".
        # f"visit ... else { }" = if nothing matched, run the else block instead.
        visit [root -->[?:Incident, name == self.incident_name]] else {
            fresh = root ++> Incident(name=self.incident_name);
            visit fresh;
        }
    }

    # Step 2 - inside the incident: find/create the person, source and claim.
    can record_claim with Incident entry {
        person = self.find_or_create_person(here);
        source = self.find_or_create_source();

        claim = Claim(
            claim_type=self.claim_type,
            value=self.claim_value,
            timestamp=self.timestamp,
            notes=self.notes
        );
        # Typed edges: Source -Asserts-> Claim -About-> Person.
        # The claim ALWAYS keeps its source. Nothing is overwritten.
        source +>:Asserts():+> claim;
        claim +>:About():+> person;

        self.created_claim_id = jid(claim);
        self.person_id = jid(person);
        log_activity(
            "IngestWalker",
            f"New report added: {source.name} says {person.name} was {plain_status(self.claim_type)}"
        );
    }

    # People are matched by exact name inside ONE incident. Fuzzy matching is
    # deliberately NOT done here - that is ResolveWalker's job (and it never
    # auto-merges).
    def find_or_create_person(incident: Incident) -> Person {
        for p in [incident ->:Involves:->] {
            if p.name == self.person_name {
                return p;
            }
        }
        person = Person(name=self.person_name, age=self.person_age);
        incident +>:Involves():+> person;
        return person;
    }

    # Sources hang off root so one Source can report on many incidents.
    def find_or_create_source() -> Source {
        for s in [root -->[?:Source]] {
            if s.name == self.source_name {
                return s;
            }
        }
        return root ++> Source(name=self.source_name, source_type=self.source_type);
    }
}
