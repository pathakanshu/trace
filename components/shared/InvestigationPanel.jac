"""A bounded report check inside the existing dashboard; no automatic paid calls."""
import from ..ui.button { Button }
sv import from ...services.trace { DashboardSnapshot, InvestigationView }
sv import from ...services.investigation { investigate_report }

# Mirrors integrations/nemotron.jac's PRICE_USD_PER_MILLION_TOKENS. A server
# glob is not shipped to the client, so the display constant is inlined here;
# keep both in sync if the price is ever configured.
glob PANEL_PRICE_USD_PER_MILLION_TOKENS: float = 0.0;

def usage_line(usage_source: str, total_tokens: int) -> str {
    if not usage_source { return ""; }
    label = "provider-reported" if usage_source == "provider" else "estimate";
    if PANEL_PRICE_USD_PER_MILLION_TOKENS <= 0.0 {
        return f"{total_tokens} tokens ({label}); price not configured";
    }
    cost = (total_tokens / 1000000.0) * PANEL_PRICE_USD_PER_MILLION_TOKENS;
    return f"{total_tokens} tokens ({label}); about ${cost:.4f}";
}

def:pub InvestigationPanel(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has selectedId: str = "", selectedClaim: str = "", passphrase: str = "",
        busy: bool = False, liveResponse: any = None, liveIncident: str = "", error: str = "";
    personId = selectedId or (snapshot.people[0].id if snapshot.people else "");
    people = [p for p in snapshot.people if p.id == personId];
    claims = people[0].claims if people else [];
    claimId = selectedClaim or (claims[-1].id if claims else "");

    # Existing runs come straight from the snapshot, so a REPLAYED result shows
    # up on load without clicking Investigate. Most recent by run_at wins.
    matching = [inv for inv in snapshot.investigations if inv.person_id == personId and inv.claim_id == claimId];
    matching.sort(key=lambda (inv: InvestigationView) -> str { return inv.run_at; });
    saved: any = matching[-1] if matching else None;

    async def investigate -> None {
        busy = True;
        error = "";
        liveResponse = None;
        try {
            response = await investigate_report(snapshot.incident_id, personId, claimId, passphrase);
            if not response {
                error = "No response received. Try again; completed checks are cached.";
            } else {
                liveResponse = response;
                liveIncident = snapshot.incident_id;
                await onRefresh();
            }
        } except Exception {
            error = "Could not check the report. Your source records have not changed.";
        }
        busy = False;
    }

    # A live call that came back UNAVAILABLE/FAILED/BUDGET_LIMIT/PARTIAL is never
    # persisted as a run, so it is shown from the fresh response, not the snapshot.
    unsavedLive: any = liveResponse if (liveIncident == snapshot.incident_id
        and liveResponse and liveResponse.get("status") in ["UNAVAILABLE", "FAILED", "BUDGET_LIMIT", "PARTIAL"]) else None;

    return <section className="mt-6 flex flex-col gap-3 rounded-md border border-border bg-card p-4" aria-label="Report investigation">
        <div>
            <h3 className="font-display text-xl">{"Investigate a report"}</h3>
            <p className="text-sm text-muted-foreground">{"Check attribution in a selected report and inspect a named source when available. Findings need human review."}</p>
        </div>
        <div className="flex flex-wrap items-end gap-3">
            <label className="flex min-w-48 flex-col gap-1 text-sm">
                <span>{"Person record"}</span>
                <select value={personId} disabled={busy}
                    onChange={lambda (e: any) { selectedId = e.target.value; selectedClaim = ""; liveResponse = None; }}
                    className="rounded-md border border-input bg-card p-2 text-foreground">
                    {for person in snapshot.people { <option key={person.id} value={person.id}>{person.name}</option> }}
                </select>
            </label>
            <label className="flex min-w-48 flex-col gap-1 text-sm">
                <span>{"Source report"}</span>
                <select value={claimId} disabled={busy}
                    onChange={lambda (e: any) { selectedClaim = e.target.value; liveResponse = None; }}
                    className="rounded-md border border-input bg-card p-2 text-foreground">
                    {for claim in claims { <option key={claim.id} value={claim.id}>{claim.source_name + " · " + claim.claim_type}</option> }}
                </select>
            </label>
            <label className="flex min-w-48 flex-col gap-1 text-sm">
                <span>{"Live passphrase (only needed for a new live check)"}</span>
                <input type="password" autoComplete="off" value={passphrase} disabled={busy}
                    onChange={lambda (e: any) { passphrase = e.target.value; }}
                    className="rounded-md border border-input bg-card p-2 text-foreground" />
            </label>
            <Button disabled={busy or not personId or not claimId} onClick={investigate}>{"Checking report…" if busy else "Investigate"}</Button>
        </div>
        {error and <p role="alert" className="text-sm text-destructive">{error}</p>}
        {unsavedLive and <div role="status" className="flex flex-col gap-2 text-sm">
            <strong>{str(unsavedLive.get("status"))}</strong>
            <p>{unsavedLive.get("message")}</p>
        </div>}
        {saved and not unsavedLive and <div role="status" className="flex flex-col gap-3 text-sm">
            <div className="flex flex-wrap items-center gap-2">
                <span className={"rounded-full border px-2 py-0.5 text-xs font-medium " +
                    ("border-status-safe/40 bg-status-safe-soft text-status-safe" if saved.mode == "LIVE" else
                     "border-status-neutral/40 bg-status-neutral-soft text-status-neutral" if saved.mode == "REPLAYED" else
                     "border-status-warning/40 bg-status-warning-soft text-status-warning")}>
                    {saved.mode}
                </span>
                <strong>{saved.status}</strong>
                <span className="text-xs text-muted-foreground">{"Model: " + saved.model}</span>
            </div>
            <p>{saved.message}</p>
            <p className="text-xs text-muted-foreground">{"Recorded run: " + (saved.run_at or "unknown") + " (viewing now)"}</p>
            {saved.usage_source and <p className="text-xs text-muted-foreground">{usage_line(saved.usage_source, saved.total_tokens)}</p>}
            {saved.trace and <ol className="list-decimal space-y-1 pl-5">
                {for step in saved.trace { <li key={step}>{step}</li> }}
            </ol>}
            {saved.citations and <div className="flex flex-col gap-2">
                <h4 className="font-medium">{"Source evidence"}</h4>
                {for citation in saved.citations { <p key={citation.claim_id} className="break-all text-xs text-muted-foreground">
                    {"Claim: " + citation.claim_id + " · Source: " + citation.source_name}
                </p> }}
            </div>}
        </div>}
        {not saved and not unsavedLive and not error and <p className="text-sm text-muted-foreground">{"No check recorded yet for this report."}</p>}
    </section>;
}
