"""Cited history from stored records; fetching it never invokes a model."""
import from .Display { friendly_time, status_label, status_badge }
sv import from ...services.timeline { person_timeline, TimelineEntry }

def:pub PersonTimeline(incidentId: str, personId: str, refreshToken: any = None) -> JsxElement {
    has entries: list[TimelineEntry] = [], loading: bool = True, error: str = "",
        requestRef: Ref[int] = Ref(0);

    async def load -> None {
        requestRef.current += 1;
        request = requestRef.current;
        entries = [];
        error = "";
        loading = True;
        try {
            rows = await person_timeline(incidentId, personId);
            if request == requestRef.current { entries = rows; }
        } except Exception {
            if request == requestRef.current { error = "The stored timeline could not load. Try refreshing the incident."; }
        } finally {
            if request == requestRef.current { loading = False; }
        }
    }
    can with [incidentId, personId, refreshToken] entry { load(); }
    can with exit { requestRef.current += 1; }
    total = entries[0].total_entries if entries else 0;

    return <section aria-label="Person change timeline" className="mt-3 min-w-0 rounded-md border border-border bg-card p-4">
        <h3 className="font-display text-xl">{"What changed?"}</h3>
        <p className="mt-1 text-sm font-medium">{"Deterministic summary from stored records"}</p>
        <p className="mt-1 text-xs text-muted-foreground">{"Ordered by source-reported time, then ingestion time. Unknown reported times come last. Status changed compares consecutive source claims."}</p>
        {loading and <p role="status" className="mt-3 text-sm text-muted-foreground">{"Loading stored history..."}</p>}
        {error and <p role="alert" className="mt-3 text-sm text-destructive">{error}</p>}
        {not loading and not error and not entries and <p className="mt-3 text-sm text-muted-foreground">{"No stored claims, alerts or investigations were found for this person in this incident."}</p>}
        {not loading and len(entries) > 0 and <p className="mt-2 text-xs text-muted-foreground">{
            ("Showing the latest " + str(len(entries)) + " of " + str(total) + " stored entries.") if total > len(entries)
            else (str(total) + " stored entries.")}</p>}
        <ol className="mt-4 flex min-w-0 flex-col gap-4 border-l border-border pl-4">
            {for entry in entries {
                <li key={entry.kind + entry.id} className="relative min-w-0 break-words text-sm">
                    <span aria-hidden="true" className="absolute -left-[21px] top-1.5 size-2 rounded-full bg-primary" />
                    <div className="flex flex-wrap items-center gap-2">
                        <strong>{entry.source_name or "Source unavailable"}</strong>
                        {entry.claim_type and <span className={"rounded-full border px-2 py-0.5 text-xs " + status_badge(entry.claim_type)}>{status_label(entry.claim_type)}</span>}
                        {entry.status_changed and <span className="rounded-full border border-status-warning/40 bg-status-warning-soft px-2 py-0.5 text-xs text-status-warning">{"status changed"}</span>}
                        {entry.kind == "alert" and <span className="rounded-full border border-border px-2 py-0.5 text-xs">{"Alert sent"}</span>}
                        {entry.kind == "investigation" and <span className="rounded-full border border-border px-2 py-0.5 text-xs">{"Investigation · " + (entry.mode or "mode unknown") + " · " + (entry.status or "status unavailable")}</span>}
                    </div>
                    <p className="mt-1 text-xs text-muted-foreground">{"Reported: " + (friendly_time(entry.reported_at) if entry.reported_at else "unknown") + " · Ingested: " + (friendly_time(entry.ingested_at) if entry.ingested_at else "unknown")}</p>
                    {entry.recorded_at and <p className="text-xs text-muted-foreground">{("Alert sent: " if entry.kind == "alert" else "Investigation recorded: ") + friendly_time(entry.recorded_at)}</p>}
                    <p className="mt-1">{entry.text}</p>
                    {entry.subscriber_names and <p className="mt-1 text-xs text-muted-foreground">{"Subscribers: " + ", ".join(entry.subscriber_names)}</p>}
                    <p className="mt-1 break-all text-xs text-muted-foreground">{"Reference: " + (entry.source_reference or "not supplied") + " · Claim: " + (entry.claim_id or "unavailable")}</p>
                    {entry.kind != "claim" and <p className="break-all text-xs text-muted-foreground">{"Stored " + entry.kind + ": " + entry.id}</p>}
                    {entry.status_changed and <p className="break-all text-xs text-muted-foreground">{"Previous claim: " + entry.previous_claim_id + " · " + entry.previous_claim_type}</p>}
                </li>
            }}
        </ol>
    </section>;
}
