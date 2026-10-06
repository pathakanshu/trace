"""PFIF import: People Finder Interchange Format 1.2 to 1.4, the XML format
Google Person Finder imports and exports. Each note becomes one sourced claim.

Names never select existing people: every PFIF person becomes a new person
record, and ResolveWalker proposes matches for a human to confirm. Notes
without a status Trace understands are skipped and listed, never guessed.
"""
import xml.etree.ElementTree as ET;
import from graph.nodes { Incident }
import from graph.edges { HasOrganization }
import from walkers.ingest { IngestWalker }
import from walkers.watch { WatchWalker }
import from demo.names { INCIDENT_NAME }

glob PFIF_MAX_CHARS: int = 200000;
glob PFIF_STATUS_TO_CLAIM: dict[str, str] = {
    "believed_missing": "MISSING",
    "believed_alive": "FOUND_SAFE",
    "is_note_author": "FOUND_SAFE",
    "believed_dead": "DECEASED"
};

obj PfifResult {
    has people: int = 0, claims_created: int = 0, duplicates: int = 0,
        alerts_created: int = 0, skipped: list[str] = [], error: str = "";
}

# Jac 0.34 RPC may turn raised exceptions into a null response, so validation
# failures come back in the result for the form to show.
def:pub import_pfif(incident_id: str, organization_id: str, xml_text: str) -> PfifResult {
    try {
        return _import_pfif(incident_id, organization_id, xml_text);
    } except ValueError as exc {
        return PfifResult(error=str(exc));
    }
}

def _local(tag: str) -> str {
    return tag.split("}", 1)[1] if "}" in tag else tag;
}

def _field(el: any, name: str) -> str {
    for child in el {
        if _local(child.tag) == name { return str(child.text or "").strip(); }
    }
    return "";
}

def _children(el: any, name: str) -> list {
    return [child for child in el if _local(child.tag) == name];
}

def _age(value: str) -> int {
    # PFIF allows a range such as "30-35"; keep the lower bound, unknown is 0.
    first = value.split("-", 1)[0].strip();
    return int(first) if first.isdigit() and int(first) <= 130 else 0;
}

def parse_pfif(xml_text: str) -> list[dict] {
    if len(xml_text) > PFIF_MAX_CHARS { raise ValueError("PFIF input is limited to 200,000 characters."); }
    lowered = xml_text.lower();
    # Entity declarations are the XML expansion attack surface; PFIF never needs them.
    if "<!doctype" in lowered or "<!entity" in lowered {
        raise ValueError("PFIF input must not contain DOCTYPE or ENTITY declarations.");
    }
    try { root_el = ET.fromstring(xml_text.strip()); }
    except ET.ParseError as exc { raise ValueError("PFIF XML could not be parsed: " + str(exc)); }
    if _local(root_el.tag) != "pfif" { raise ValueError("Expected a <pfif:pfif> root element."); }
    people: dict[str, dict] = {};
    order: list[str] = [];
    for person in _children(root_el, "person") {
        record_id = _field(person, "person_record_id");
        if not record_id { continue; }
        name = _field(person, "full_name")
            or (_field(person, "given_name") + " " + _field(person, "family_name")).strip()
            or (_field(person, "first_name") + " " + _field(person, "last_name")).strip();
        people[record_id] = {"record_id": record_id, "name": name,
            "age": _age(_field(person, "age")), "notes": list(_children(person, "note"))};
        order.append(record_id);
    }
    # PFIF also allows notes at the top level, linked by person_record_id.
    for note in _children(root_el, "note") {
        record_id = _field(note, "person_record_id");
        if record_id in people { people[record_id]["notes"].append(note); }
        else { people[record_id or "(missing person_record_id)"] = {"record_id": record_id, "name": "", "age": 0, "notes": [note], "orphan": True}; order.append(record_id or "(missing person_record_id)"); }
    }
    return [people[key] for key in order];
}

def _claim_type(note: any) -> str {
    status = _field(note, "status").lower();
    if status in PFIF_STATUS_TO_CLAIM { return PFIF_STATUS_TO_CLAIM[status]; }
    if not status and _field(note, "last_known_location") { return "SEEN_AT_LOCATION"; }
    return "";
}

def _import_pfif(incident_id: str, organization_id: str, xml_text: str) -> PfifResult {
    incidents = [i for i in [root -->[?:Incident]] if jid(i) == incident_id and i.name == INCIDENT_NAME];
    if not incidents { raise ValueError("Demo incident changed. Refresh before importing."); }
    incident = incidents[0];
    orgs = [o for o in [incident ->:HasOrganization:->] if jid(o) == organization_id];
    if not orgs { raise ValueError("Select the organization that is publishing these records."); }
    records = parse_pfif(xml_text);
    if not records { raise ValueError("No PFIF person or note records were found."); }
    result = PfifResult();
    for record in records {
        record_id = str(record["record_id"]);
        name = str(record["name"]);
        age = int(record["age"]);
        notes: list = record["notes"];
        if record.get("orphan") or not name {
            result.skipped.append(record_id + ": no person record with a name in this file");
            continue;
        }
        person_id = "";
        for note in notes {
            note_id = _field(note, "note_record_id");
            claim_type = _claim_type(note);
            if not note_id { result.skipped.append(record_id + ": a note has no note_record_id"); continue; }
            if not claim_type {
                status = _field(note, "status") or "no status";
                result.skipped.append(note_id + ": status '" + status + "' is not a person status Trace records");
                continue;
            }
            text = _field(note, "text");
            location = _field(note, "last_known_location");
            summary = text or ("Last known location: " + location if location else claim_type);
            if location and text { summary = text + " Last known location: " + location; }
            # One bad note (unparseable time, changed content under a reused id) is
            # reported and skipped; the rest of the file still imports.
            try {
                ingested = root spawn IngestWalker(
                    incident_name=incident.name, selected_person_id=person_id,
                    person_name=name, person_age=age, source_name=orgs[0].name,
                    organization_id=organization_id, claim_type=claim_type,
                    claim_value=summary[:2000], timestamp=_field(note, "source_date"),
                    source_reference=note_id,
                    original_content=ET.tostring(note, encoding="unicode")[:10000],
                    notes="PFIF person " + record_id + "; note author: " + (_field(note, "author_name") or "not given"),
                    extraction_method="pfif_import"
                );
                # Later notes for the same PFIF person attach to the record the first note created.
                person_id = ingested.person_id;
                if ingested.duplicate { result.duplicates += 1; }
                else { result.claims_created += 1; }
            } except ValueError as exc {
                result.skipped.append(note_id + ": " + str(exc));
            }
        }
        if person_id { result.people += 1; }
    }
    watcher = root spawn WatchWalker(incident_id=incident_id);
    result.alerts_created = watcher.alerts_created;
    return result;
}
