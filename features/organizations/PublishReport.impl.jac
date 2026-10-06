impl PublishReport.loadExample -> None {
    hospitals = [o for o in snapshot.organizations if o.organization_type == "HOSPITAL"];
    people = [p for p in snapshot.people if p.name == "Maya Gurung"];
    organizationId = hospitals[0].id if hospitals else "";
    personId = people[0].id if len(people) == 1 else "";
    claimType = "FOUND_SAFE";
    summary = "Admitted, stable condition";
    reportedAt = "2026-09-21T09:15";
    reference = "HOSPITAL-FORM-001";
    original = "Fictional hospital intake report: Maya Gurung, age 24, was admitted in stable condition at 09:15 UTC on 21 September 2026.";
    reviewing = False;
    error = "";
    notice = "Example loaded. Check the selected person and review before publishing.";
}

impl PublishReport.review(event: any) -> None {
    event.preventDefault();
    error = "";
    notice = "";
    if not selectedOrg or not selectedPerson {
        error = "Select a current organization and person record.";
        return;
    }
    if not reference.strip() or not summary.strip() or not original.strip() {
        error = "Report reference, summary, and original text are required.";
        return;
    }
    reviewing = True;
}

impl PublishReport.publish -> None {
    busy = True;
    error = "";
    notice = "";
    try {
        result = await publish_report(incident_id=snapshot.incident_id,
            organization_id=organizationId, person_id=personId, claim_type=claimType,
            summary=summary, reported_at=reportedAt, source_reference=reference,
            original_content=original, passphrase=edit_key());
        if not result {
            error = "No response received. Keep the same report reference and retry to avoid duplicates.";
            busy = False;
            return;
        }
        if result.error {
            error = result.error;
            busy = False;
            return;
        }
        notice = ("Already published; no duplicate claim. " if result.duplicate else "Report published. ") + str(result.alerts_created) + " new alert(s). Claim: " + result.claim_id;
        reviewing = False;
        await onRefresh();
    } except Exception as e {
        error = "Could not publish: " + str(e);
    }
    busy = False;
}
