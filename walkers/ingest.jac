"""Validated structured ingestion. An explicit person ID associates a report;
without one, a new person record is created for later human review.
Repeated report IDs are idempotent; changed content must use a new reference.
"""
import hashlib;
import json;
import from datetime { datetime, timezone }
import from graph.nodes { Incident, Person, Claim, Source, Organization }
import from graph.edges { Involves, Asserts, About, HasOrganization, Publishes }
import from graph.activity { log_activity, plain_status, now_iso }

glob REPORT_TYPES: list[str] = ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED", "SEEN_AT_LOCATION"];
glob INSTITUTION_TYPES: list[str] = ["POLICE", "HOSPITAL", "NGO", "GOVERNMENT"];

def normalize_report_time(value: str) -> str {
    if not value.strip() { return ""; }
    try {
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"));
        # The structured demo form and legacy fixtures explicitly use UTC.
        if parsed.tzinfo == None { parsed = parsed.replace(tzinfo=timezone.utc); }
        return parsed.astimezone(timezone.utc).isoformat(timespec="seconds");
    } except ValueError {
        raise ValueError("Reported time must be a valid ISO date/time, or blank if unknown.");
    }
}

walker IngestWalker {
    has incident_name: str, person_name: str, source_name: str, claim_type: str,
        person_age: int = 0, source_type: str = "", claim_value: str = "",
        timestamp: str = "", notes: str = "",
        selected_person_id: str = "", organization_id: str = "",
        source_reference: str = "", original_content: str = "",
        extraction_method: str = "structured_input";
    has created_claim_id: str = "", person_id: str = "", duplicate: bool = False;

    can find_incident with Root entry {
        self.incident_name = self.incident_name.strip();
        self.person_name = self.person_name.strip();
        self.source_name = self.source_name.strip();
        self.source_reference = self.source_reference.strip();
        if not self.incident_name or not self.person_name or not self.source_name {
            raise ValueError("Incident, person, and source are required.");
        }
        if self.claim_type not in REPORT_TYPES { raise ValueError("Unsupported report status."); }
        if self.person_age < 0 or self.person_age > 130 { raise ValueError("Age is outside the allowed range."); }
        if len(self.claim_value) > 2000 or len(self.notes) > 5000 or len(self.original_content) > 10000 {
            raise ValueError("Report is too long. Limit summary to 2000 and original text to 10000 characters.");
        }
        if len(self.source_reference) > 300 or len(self.source_name) > 200 or len(self.person_name) > 200 {
            raise ValueError("Person, source, or report reference is too long.");
        }
        self.timestamp = normalize_report_time(self.timestamp);
        visit [root -->[?:Incident, name == self.incident_name]] else {
            if self.selected_person_id or self.organization_id {
                raise ValueError("Incident no longer exists. Refresh before publishing.");
            }
            fresh = root ++> Incident(name=self.incident_name);
            visit fresh;
        }
    }

    can record_claim with Incident entry {
        # Validate existing IDs before writing any nodes. Names never select people.
        person: Person | None = None;
        if self.selected_person_id {
            matches = [p for p in [here ->:Involves:->] if jid(p) == self.selected_person_id];
            if not matches { raise ValueError("Selected person is not in this incident. Refresh and select again."); }
            person = matches[0];
        }
        organization: Organization | None = None;
        if self.organization_id {
            orgs = [o for o in [here ->:HasOrganization:->] if jid(o) == self.organization_id];
            if not orgs { raise ValueError("Selected organization is not in this incident. Refresh and select again."); }
            organization = orgs[0];
            self.source_name = organization.name;
            self.source_type = organization.organization_type;
        }
        payload = json.dumps([
            self.selected_person_id or self.person_name, self.person_age,
            self.source_name, self.source_type, self.claim_type, self.claim_value,
            self.timestamp, self.notes, self.original_content, self.extraction_method
        ], ensure_ascii=False);
        payload_hash = hashlib.sha256(payload.encode()).hexdigest();
        key = hashlib.sha256(json.dumps([
            jid(here), self.source_name, self.source_type,
            self.source_reference or payload_hash
        ]).encode()).hexdigest();
        for p in [here ->:Involves:->] {
            for c in [p <-:About:<-] {
                if c.ingestion_key == key {
                    if c.payload_hash != payload_hash {
                        raise ValueError("That organization already published this report reference with different content. Use a new reference for a correction.");
                    }
                    self.created_claim_id = jid(c);
                    self.person_id = jid(p);
                    self.duplicate = True;
                    return;
                }
            }
        }
        if not person {
            person = Person(name=self.person_name, age=self.person_age);
            here +>:Involves():+> person;
        }
        if not organization and self.source_type in INSTITUTION_TYPES {
            orgs = [o for o in [here ->:HasOrganization:->]
                if o.name == self.source_name and o.organization_type == self.source_type];
            if orgs { organization = orgs[0]; }
            else {
                organization = Organization(name=self.source_name, organization_type=self.source_type);
                here +>:HasOrganization():+> organization;
            }
        }
        # Each source record belongs to one report; the organization is reusable.
        source = root ++> Source(name=self.source_name, source_type=self.source_type);
        if organization { organization +>:Publishes():+> source; }
        claim = Claim(
            claim_type=self.claim_type, value=self.claim_value,
            timestamp=self.timestamp, notes=self.notes, incident_id=jid(here),
            ingested_at=now_iso(), original_content=self.original_content or self.notes,
            source_reference=self.source_reference, extraction_method=self.extraction_method,
            ingestion_key=key, payload_hash=payload_hash
        );
        source +>:Asserts():+> claim;
        claim +>:About():+> person;
        self.created_claim_id = jid(claim);
        self.person_id = jid(person);
        log_activity("IngestWalker",
            f"Report preserved: {source.name} says {person.name} was {plain_status(self.claim_type)}",
            jid(here));
    }
}
