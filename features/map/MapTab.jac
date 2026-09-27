"""Reported-location inspector. Evidence follows real media/claim graph edges."""
import from .IncidentMap { IncidentMap }
import from .Density { aggregate_places }
import from .Status { linked_people, pin_status, pin_label, pin_dot, current_reports }
import from ...components.shared.Display { SectionHeading, friendly_time, status_sentence }
sv import from ...services.trace { DashboardSnapshot, LocationView }

def:pub MapTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], active: bool = True, focusLocationId: str = "", focusRequest: int = 0) -> JsxElement {
    has selectedId: str = "",
        selectedSettlement: str = "",
        settlementAnchors: list = [];
    # Additive snapshot compatibility while the count endpoint is integrating.
    counts: list[dict] = (snapshot as any).place_counts or [];
    groups: list[dict] = aggregate_places(counts, settlementAnchors);
    located: int = (snapshot as any).located_reports or 0;
    unlocated: int = (snapshot as any).unlocated_reports or 0;
    show_places: bool = not snapshot.is_corpus and (len(snapshot.locations) <= 20 or len(groups) == 0);
    selectedGroups: list[dict] = [g for g in groups if g["key"] == selectedSettlement];
    def choose_settlement(key: str) -> None { selectedSettlement = key; selectedId = ""; }
    def choose_place(id: str) -> None { selectedId = id; selectedSettlement = ""; }
    can with [focusLocationId, focusRequest] entry {
        if focusRequest > 0 and focusLocationId in [p.id for p in snapshot.locations] {
            selectedId = focusLocationId;
            selectedSettlement = "";
        }
    }
    selected = [place for place in snapshot.locations if place.id == selectedId];
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Map" subtitle="Select a reported place to inspect its linked evidence and sources." />
        <div className="h-[50svh] min-h-80">
            <IncidentMap locations={snapshot.locations} people={snapshot.people} active={active} focusLocationId={focusLocationId} focusRequest={focusRequest} onSelect={choose_place} reportGroups={groups} onSelectSettlement={choose_settlement} onCorridorReady={lambda (features: list) { settlementAnchors = features; }} />
        </div>
        <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs" aria-label="Map status legend">
            {for status in (["MISSING", "REVIEW", "FOUND_SAFE", "UNKNOWN"] if show_places else []) {
                <span key={status} className="inline-flex items-center gap-2">
                    <span className={"size-2.5 rounded-full " + pin_dot(status)} aria-hidden="true" />{pin_label(status)}
                </span>
            }}
            <span className="inline-flex items-center gap-2"><span className="h-1 w-5 bg-status-warning" aria-hidden="true" />{"Affected river: Bhote Koshi"}</span>
            <span className="inline-flex items-center gap-2"><span className="h-0.5 w-5 bg-map-water" aria-hidden="true" />{"Other rivers (Natural Earth)"}</span>
        </div>
        {show_places and <p className="text-xs text-muted-foreground">{"Pin colour follows linked people's current reports; needs review includes conflicting reports, injury, or death. District outline: Sindhupalchok. Pins are reported media locations, not live person tracking. Unknown or invalid coordinates are omitted."}</p>}
        <p className="min-w-0 break-words text-xs text-muted-foreground" aria-label="River corridor context">{"Bhote Koshi river corridor (current OpenStreetMap linework). Not a measured 2016 flood extent. The translucent band is a visual guide along the river."}</p>
        {(len(counts) > 0 or located > 0 or unlocated > 0) and <section className="min-w-0 flex flex-col gap-3" aria-label="Report density">
            <p className="break-words text-sm" aria-live="polite">{str(located) + " reports with a location, clustered at " + str(len(groups)) + " settlements; " + str(unlocated) + " reports have no verified location."}</p>
            <p className="text-xs text-muted-foreground">{"Heat shows report counts, not unique people, image locations or flood severity. Reports at the same coordinates stay together; the glow is a display effect, not an uncertainty boundary."}</p>
            <div className="flex flex-wrap items-center gap-2 text-xs" aria-label="Report density legend">
                <span className="size-3 rounded-full bg-primary" aria-hidden="true" />{"Fewer reports"}
                <span className="size-3 rounded-full bg-status-warning" aria-hidden="true" />
                <span className="size-3 rounded-full bg-status-missing" aria-hidden="true" />{"More reports"}
            </div>
            <div className="flex flex-wrap gap-2" aria-label="Busiest report settlements">
                {for group in groups[:20] {
                    <button key={group["key"]} type="button" aria-pressed={selectedSettlement == group["key"]}
                        onClick={lambda { choose_settlement(str(group["key"])); }}
                        className={"min-w-0 max-w-full break-words rounded-md border px-3 py-2 text-left text-sm focus-visible:ring-2 focus-visible:ring-ring " + ("border-primary bg-accent text-primary" if selectedSettlement == group["key"] else "border-border bg-card")}>
                        {str(group["name"]) + " · " + str(group["report_count"]) + " reports"}
                    </button>
                }}
            </div>
            {len(groups) > 20 and <p className="text-xs text-muted-foreground">{"Showing the 20 busiest settlements. All valid report counts remain on the map."}</p>}
            {for group in selectedGroups {
                <section key={group["key"]} className="min-w-0 break-words rounded-md border border-border bg-card p-4" aria-label="Settlement report counts">
                    <h3 className="font-display text-xl">{group["name"]}</h3>
                    <p className="mt-2 text-sm">{str(group["report_count"]) + " reports · " + str(group["missing"]) + " missing · " + str(group["safe"]) + " safe · " + str(group["other"]) + " other"}</p>
                    <p className="mt-1 text-xs text-muted-foreground">{str(len(group["location_ids"])) + " location records share this coordinate. These are source report assertions, not reconciled person outcomes."}</p>
                </section>
            }}
        </section>}
        {show_places and <>
        <div className="flex flex-wrap gap-2" aria-label="Reported places">
            {for place in snapshot.locations[:20] {
                <button key={place.id} type="button" aria-pressed={selectedId == place.id}
                    onClick={lambda { choose_place(place.id); }}
                    className={"inline-flex max-w-full items-center gap-2 rounded-md border px-3 py-2 text-left text-sm focus-visible:ring-2 focus-visible:ring-ring " + ("border-primary bg-accent text-primary" if selectedId == place.id else "border-border bg-card")}>
                    <span className={"size-2.5 shrink-0 rounded-full " + pin_dot(pin_status(linked_people(place, snapshot.people)))} aria-hidden="true" />
                    <span className="break-words">{place.name + " · " + pin_label(pin_status(linked_people(place, snapshot.people)))}</span>
                </button>
            }}
        </div>
        {len(snapshot.locations) > 20 and <p className="text-xs text-muted-foreground">{"Showing the first 20 reported places while report counts are unavailable."}</p>}
        </>}
        {not selected and not selectedGroups and <p className="text-sm text-muted-foreground">{"Choose a pin or a place above. The place list remains available if the map cannot load."}</p>}
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
