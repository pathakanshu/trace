"""Reported-location inspector. Evidence follows real media/claim graph edges."""
import from .IncidentMap { IncidentMap }
import from .Status { linked_people, pin_status, pin_label, pin_dot, current_reports }
import from ...components.shared.Display { SectionHeading, friendly_time, status_sentence }
sv import from ...services.trace { DashboardSnapshot, LocationView }

def:pub MapTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], active: bool = True) -> JsxElement {
    has selectedId: str = "";
    selected = [place for place in snapshot.locations if place.id == selectedId];
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Map" subtitle="Select a reported place to inspect its linked evidence and sources." />
        <div className="h-[50svh] min-h-80">
            <IncidentMap locations={snapshot.locations} people={snapshot.people} active={active} onSelect={lambda (id: str) { selectedId = id; }} />
        </div>
        <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs" aria-label="Map status legend">
            {for status in ["MISSING", "REVIEW", "FOUND_SAFE", "UNKNOWN"] {
                <span key={status} className="inline-flex items-center gap-2">
                    <span className={"size-2.5 rounded-full " + pin_dot(status)} aria-hidden="true" />{pin_label(status)}
                </span>
            }}
        </div>
        <p className="text-xs text-muted-foreground">{"Pin colour follows linked people's current reports; needs review includes conflicting reports, injury, or death. Shaded area: Sindhupalchok district. Pins are reported media locations, not live person tracking. Unknown or invalid coordinates are omitted."}</p>
        <div className="flex flex-wrap gap-2" aria-label="Reported places">
            {for place in snapshot.locations {
                <button key={place.id} type="button" aria-pressed={selectedId == place.id}
                    onClick={lambda { selectedId = place.id; }}
                    className={"inline-flex max-w-full items-center gap-2 rounded-md border px-3 py-2 text-left text-sm focus-visible:ring-2 focus-visible:ring-ring " + ("border-primary bg-accent text-primary" if selectedId == place.id else "border-border bg-card")}>
                    <span className={"size-2.5 shrink-0 rounded-full " + pin_dot(pin_status(linked_people(place, snapshot.people)))} aria-hidden="true" />
                    <span className="break-words">{place.name + " · " + pin_label(pin_status(linked_people(place, snapshot.people)))}</span>
                </button>
            }}
        </div>
        {not selected and <p className="text-sm text-muted-foreground">{"Choose a pin or a place above. The place list remains available if the map cannot load."}</p>}
        {for place in selected { <LocationEvidencePanel key={place.id} selected={place} snapshot={snapshot} /> }}

    </div>;
}

def LocationEvidencePanel(selected: LocationView, snapshot: DashboardSnapshot) -> JsxElement {
    people = linked_people(selected, snapshot.people);
    return <section className="min-w-0 break-words flex flex-col gap-4 rounded-md border border-border bg-card p-4" aria-label="Location evidence">
            <div>
                <h3 className="font-display text-2xl">{selected.name}</h3>
                <p className="text-sm text-status-warning">{selected.basis}</p>
                <p className="mt-1 text-xs text-muted-foreground">{str(selected.latitude) + ", " + str(selected.longitude) + " · Location: " + selected.id}</p>
            </div>
            <div className="flex min-w-0 flex-col gap-3" aria-label="Current reports for linked people" aria-live="polite">
                <h4 className="font-medium">{"Current reports for linked people"}</h4>
                <p className="text-xs text-muted-foreground">{"These are person status reports, not evidence that the person is currently at this pin."}</p>
                {not people and <p className="text-sm text-muted-foreground">{"No person is linked by a report at this place."}</p>}
                {for person in people {
                    <article key={person.id} className="rounded-md border border-border p-3 text-sm">
                        <p className="font-medium">{person.name + " · " + (status_sentence(person.latest_status) if person.latest_status != "UNKNOWN" else "Current status unknown")}</p>
                        {person.has_conflict and <p className="text-status-warning">{"Reports disagree; review the cited sources."}</p>}
                        <p className="text-xs text-muted-foreground">{person.status_summary}</p>
                        {for claim in current_reports(person) {
                            <p key={claim.id} className="mt-2 text-xs text-muted-foreground">
                                {claim.source_name + " · " + status_sentence(claim.claim_type) + " · " + friendly_time(claim.timestamp)}
                                <span className="block break-all">{"Reference: " + (claim.source_reference or "unknown") + " · Claim: " + claim.id}</span>
                            </p>
                        }}
                    </article>
                }}
            </div>
            <div className="grid min-w-0 gap-4 md:grid-cols-2">
                <div className="flex min-w-0 flex-col gap-3">
                    <h4 className="font-medium">{"Linked reports"}</h4>
                    {len(selected.evidence) == 0 and <p className="text-sm text-muted-foreground">{"No claim links to media at this place. A map pin alone does not establish a person's location."}</p>}
                    {for evidence in selected.evidence {
                        <article key={evidence.claim_id} className="border-l-2 border-primary pl-3 text-sm">
                            <p className="font-medium">{evidence.person_name + " · " + status_sentence(evidence.claim_type)}</p>
                            <p>{evidence.summary}</p>
                            <p className="mt-1 text-xs text-muted-foreground">{evidence.source_name + " · " + friendly_time(evidence.reported_at)}</p>
                            <p className="break-all text-xs text-muted-foreground">{"Reference: " + (evidence.source_reference or "unknown") + " · Claim: " + evidence.claim_id}</p>
                        </article>
                    }}
                </div>
                <div className="flex min-w-0 flex-col gap-3">
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
