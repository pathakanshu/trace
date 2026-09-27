"""A bounded report check inside the existing dashboard; no automatic paid calls."""
import from ..ui.button { Button }
sv import from ...services.trace { DashboardSnapshot }
sv import from ...services.investigation { investigate_report }

def:pub InvestigationPanel(snapshot: DashboardSnapshot) -> JsxElement {
    has selectedId: str = "", selectedClaim: str = "", busy: bool = False, result: any = None, resultIncident: str = "", error: str = "";
    personId = selectedId or (snapshot.people[0].id if snapshot.people else "");
    people = [p for p in snapshot.people if p.id == personId];
    claims = people[0].claims if people else [];
    claimId = selectedClaim or (claims[-1].id if claims else "");
    async def investigate -> None {
        busy = True;
        error = "";
        result = None;
        try {
            # The passphrase field arrives with the panel update; until then only
            # saved and recorded results can be shown.
            response = await investigate_report(snapshot.incident_id, personId, claimId, "");
            result = response;
            resultIncident = snapshot.incident_id;
            if not response { error = "No response received. Try again; completed checks are cached."; }
        } except Exception {
            error = "Could not check the report. Your source records have not changed.";
        }
        busy = False;
    }
    visible: any = result if resultIncident == snapshot.incident_id else None;
    return <section className="mt-6 flex flex-col gap-3 rounded-md border border-border bg-card p-4" aria-label="Report investigation">
        <div>
            <h3 className="font-display text-xl">{"Investigate a report"}</h3>
            <p className="text-sm text-muted-foreground">{"Check attribution in a selected report and inspect a named source when available. Findings need human review."}</p>
        </div>
        <div className="flex flex-wrap items-end gap-3">
            <label className="flex min-w-48 flex-col gap-1 text-sm">
                <span>{"Person record"}</span>
                <select value={personId} disabled={busy}
                    onChange={lambda (e: any) { selectedId = e.target.value; selectedClaim = ""; result = None; }}
                    className="rounded-md border border-input bg-card p-2 text-foreground">
                    {for person in snapshot.people { <option key={person.id} value={person.id}>{person.name}</option> }}
                </select>
            </label>
            <label className="flex min-w-48 flex-col gap-1 text-sm">
                <span>{"Source report"}</span>
                <select value={claimId} disabled={busy}
                    onChange={lambda (e: any) { selectedClaim = e.target.value; result = None; }}
                    className="rounded-md border border-input bg-card p-2 text-foreground">
                    {for claim in claims { <option key={claim.id} value={claim.id}>{claim.source_name + " · " + claim.claim_type}</option> }}
                </select>
            </label>
            <Button disabled={busy or not personId or not claimId} onClick={investigate}>{"Checking report…" if busy else "Investigate"}</Button>
        </div>
        {error and <p role="alert" className="text-sm text-destructive">{error}</p>}
        {visible and <div role="status" className="flex flex-col gap-3 text-sm">
            <strong>{str(visible.status) + (" · saved result" if visible.cached else "")}</strong>
            <p>{visible.message}</p>
            {visible.scope and <p className="text-muted-foreground">{visible.scope}</p>}
            {visible.trace and <ol className="list-decimal space-y-1 pl-5">
                {for step in visible.trace { <li key={step}>{step}</li> }}
            </ol>}
            {visible.citations and <div className="flex flex-col gap-2">
                <h4 className="font-medium">{"Source evidence"}</h4>
                {for citation in visible.citations {
                    <details key={citation.claim_id} className="rounded border border-border p-2">
                        <summary className="cursor-pointer">{str(citation.source_name) + " · " + str(citation.reported_at or "Reported time unknown")}</summary>
                        <p className="mt-2 whitespace-pre-wrap">{citation.excerpt}</p>
                        <p className="mt-2 break-all text-xs text-muted-foreground">{"Claim: " + citation.claim_id + " · Reference: " + (citation.reference or "not supplied")}</p>
                    </details>
                }}
            </div>}
        </div>}
    </section>;
}
