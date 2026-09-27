"""Reported-location inspector. Evidence follows real media/claim graph edges."""
import from .IncidentMap { IncidentMap }
import from ...components.shared.Display { SectionHeading, friendly_time, status_sentence }
sv import from ...services.trace { DashboardSnapshot, LocationView }

def:pub MapTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], active: bool = True) -> JsxElement {
    has selectedId: str = "";
    selected = [place for place in snapshot.locations if place.id == selectedId];
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Map" subtitle="Select a reported place to inspect its linked evidence and sources." />
        <div className="h-[50svh] min-h-80">
            <IncidentMap locations={snapshot.locations} active={active} onSelect={lambda (id: str) { selectedId = id; }} />
        </div>
        <p className="text-xs text-muted-foreground">{"Shaded area: Sindhupalchok district. Pins are reported media locations, not live person tracking. Unknown or invalid coordinates are omitted."}</p>
        <div className="flex flex-wrap gap-2" aria-label="Reported places">
            {for place in snapshot.locations {
                <button key={place.id} type="button" aria-pressed={selectedId == place.id}
                    onClick={lambda { selectedId = place.id; }}
                    className={"rounded-md border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-ring " + ("border-primary bg-accent text-primary" if selectedId == place.id else "border-border bg-card")}>
                    {place.name}
                </button>
            }}
        </div>
        {not selected and <p className="text-sm text-muted-foreground">{"Choose a pin or a place above. The place list remains available if the map cannot load."}</p>}
        {for place in selected { <LocationEvidencePanel key={place.id} selected={place} snapshot={snapshot} /> }}

    </div>;
}

def LocationEvidencePanel(selected: LocationView, snapshot: DashboardSnapshot) -> JsxElement {
    return <section className="flex flex-col gap-4 rounded-md border border-border bg-card p-4" aria-label="Location evidence">
            <div>
                <h3 className="font-display text-2xl">{selected.name}</h3>
                <p className="text-sm text-status-warning">{selected.basis}</p>
                <p className="mt-1 text-xs text-muted-foreground">{str(selected.latitude) + ", " + str(selected.longitude) + " · Location: " + selected.id}</p>
            </div>
            <div className="grid gap-4 md:grid-cols-2">
                <div className="flex flex-col gap-3">
                    <h4 className="font-medium">{"Linked reports"}</h4>
                    {len(selected.evidence) == 0 and <p className="text-sm text-muted-foreground">{"No claim links to media at this place. A map pin alone does not establish a person's location."}</p>}
                    {for evidence in selected.evidence {
                        <article key={evidence.claim_id} className="border-l-2 border-primary pl-3 text-sm">
                            <p className="font-medium">{evidence.person_name + " · " + status_sentence(evidence.claim_type)}</p>
                            <p>{evidence.summary}</p>
                            <p className="mt-1 text-xs text-muted-foreground">{evidence.source_name + " · " + friendly_time(evidence.reported_at)}</p>
                            <p className="break-words text-xs text-muted-foreground">{"Reference: " + (evidence.source_reference or "unknown") + " · Claim: " + evidence.claim_id}</p>
                        </article>
                    }}
                </div>
                <div className="flex flex-col gap-3">
                    <h4 className="font-medium">{"Linked media"}</h4>
                    {for media in snapshot.media {
                        if media.id in selected.media_ids {
                            <article key={media.id} className="rounded-md border border-border p-3 text-sm">
                                <p>{media.description}</p>
                                <p className="mt-1 text-xs text-muted-foreground">{"Reported capture: " + friendly_time(media.captured_at)}</p>
                                <p className="break-all text-xs text-muted-foreground">{"Media: " + media.id}</p>
                            </article>
                        }
                    }}
                    <p className="text-xs text-muted-foreground">{"Seeded media are simulated. The graph link is not an independent geolocation check."}</p>
                </div>
            </div>
        </section>;
}
