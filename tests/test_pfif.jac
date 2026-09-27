"""PFIF import, offline: statuses map to claims, re-import is idempotent,
unknown statuses are skipped with a reason, and entity declarations are refused."""
import from services.trace { reset_demo, get_dashboard }
import from features.organizations.pfif { import_pfif, parse_pfif }

glob SAMPLE: str = """<?xml version="1.0" encoding="UTF-8"?>
<pfif:pfif xmlns:pfif="http://zesty.ca/pfif/1.4">
  <pfif:person>
    <pfif:person_record_id>example.org/p-001</pfif:person_record_id>
    <pfif:full_name>Ram Thapa</pfif:full_name>
    <pfif:age>41</pfif:age>
    <pfif:note>
      <pfif:note_record_id>example.org/n-001</pfif:note_record_id>
      <pfif:person_record_id>example.org/p-001</pfif:person_record_id>
      <pfif:author_name>Family member</pfif:author_name>
      <pfif:source_date>2026-09-20T09:00:00Z</pfif:source_date>
      <pfif:status>believed_missing</pfif:status>
      <pfif:last_known_location>Bahrabise bazaar</pfif:last_known_location>
      <pfif:text>Not heard from since the flood.</pfif:text>
    </pfif:note>
    <pfif:note>
      <pfif:note_record_id>example.org/n-002</pfif:note_record_id>
      <pfif:person_record_id>example.org/p-001</pfif:person_record_id>
      <pfif:source_date>2026-09-21T11:30:00Z</pfif:source_date>
      <pfif:status>believed_alive</pfif:status>
      <pfif:text>Registered at the Khadichaur shelter.</pfif:text>
    </pfif:note>
    <pfif:note>
      <pfif:note_record_id>example.org/n-003</pfif:note_record_id>
      <pfif:person_record_id>example.org/p-001</pfif:person_record_id>
      <pfif:status>information_sought</pfif:status>
      <pfif:text>Does anyone have news?</pfif:text>
    </pfif:note>
  </pfif:person>
</pfif:pfif>""";

def demo_ids -> tuple {
    reset_demo();
    snap = get_dashboard();
    return (snap.incident_id, snap.organizations[0].id);
}

test "PFIF notes become cited claims on one new person" {
    ids = demo_ids();
    before = len(get_dashboard().people);
    result = import_pfif(ids[0], ids[1], SAMPLE);
    assert result.error == "";
    assert result.people == 1 and result.claims_created == 2 and result.duplicates == 0;
    assert len(result.skipped) == 1 and "information_sought" in result.skipped[0];
    snap = get_dashboard();
    assert len(snap.people) == before + 1;
    ram = [p for p in snap.people if p.name == "Ram Thapa"][0];
    assert ram.age == 41;
    assert sorted([c.claim_type for c in ram.claims]) == ["FOUND_SAFE", "MISSING"];
    assert all([c.extraction_method == "pfif_import" and "example.org/n-00" in c.original_content and "believed_" in c.original_content for c in ram.claims]);
    assert "example.org/n-001" in [c.source_reference for c in ram.claims];
}

test "re-importing the same PFIF file creates nothing" {
    ids = demo_ids();
    import_pfif(ids[0], ids[1], SAMPLE);
    count = len(get_dashboard().people);
    again = import_pfif(ids[0], ids[1], SAMPLE);
    assert again.claims_created == 0 and again.duplicates == 2;
    assert len(get_dashboard().people) == count;
}

test "entity declarations and malformed XML are refused" {
    ids = demo_ids();
    evil = '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY a "aaaa">]><pfif:pfif xmlns:pfif="http://zesty.ca/pfif/1.4"/>';
    assert "DOCTYPE" in import_pfif(ids[0], ids[1], evil).error;
    assert "could not be parsed" in import_pfif(ids[0], ids[1], "<pfif:pfif").error;
    assert import_pfif(ids[0], "not-an-org", SAMPLE).error != "";
}

test "PFIF 1.2 top-level notes attach by person_record_id" {
    xml = """<pfif:pfif xmlns:pfif="http://zesty.ca/pfif/1.2">
      <pfif:person><pfif:person_record_id>ex/p</pfif:person_record_id>
        <pfif:first_name>Sita</pfif:first_name></pfif:person>
      <pfif:note><pfif:note_record_id>ex/n</pfif:note_record_id>
        <pfif:person_record_id>ex/p</pfif:person_record_id>
        <pfif:status>believed_dead</pfif:status></pfif:note>
    </pfif:pfif>""";
    records = parse_pfif(xml);
    assert len(records) == 1 and records[0]["name"] == "Sita" and len(records[0]["notes"]) == 1;
}
