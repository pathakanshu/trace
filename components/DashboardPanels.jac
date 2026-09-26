"""Dashboard panels - each one is a different VIEW over the same Trace graph.

These are stateless: TraceDashboard fetches the snapshot and passes pieces in
as props. To change how something looks, edit the panel here; to change what
data exists, edit services/trace.jac.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    MapsLocation01Icon, UserMultipleIcon, Image01Icon, Notification01Icon,
    GitBranchIcon, Alert02Icon, UserSearch01Icon, Activity01Icon, Location01Icon
}
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.badge { Badge }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from .ui.alert { Alert, AlertTitle, AlertDescription }
import from ..lib.utils { cn }
sv import from ..services.trace {
    PersonView, ClaimView, MediaView, LocationView, AlertView, ActivityView
}
sv import from ..walkers.resolve { DuplicateCandidate }

# Colour for a claim type badge. Status colours only mean real state.
def status_class(claim_type: str) -> str {
    if claim_type == "MISSING" {
        return "bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/30";
    }
    if claim_type == "FOUND_SAFE" {
        return "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-500/30";
    }
    if claim_type == "INJURED" {
        return "bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/30";
    }
    return "bg-muted text-muted-foreground border-border";
}

def confidence_class(confidence: str) -> str {
    if confidence == "HIGH" { return "text-emerald-700 dark:text-emerald-300"; }
    if confidence == "MEDIUM" { return "text-amber-700 dark:text-amber-300"; }
    return "text-muted-foreground";
}

# "2026-09-21T09:15:00" -> "Sep 21, 09:15"
def short_time(iso: str) -> str {
    if len(iso) < 16 { return iso; }
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    month = months[int(iso[5:7]) - 1];
    return month + " " + str(int(iso[8:10])) + ", " + iso[11:16];
}

def PanelTitle(icon: any, title: str, subtitle: str) -> JsxElement {
    return <div className="flex items-start gap-3">
        <div className="flex size-8 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
            <HugeiconsIcon icon={icon} strokeWidth={2} className="size-4" />
        </div>
        <div className="flex flex-col gap-0.5">
            <CardTitle>{title}</CardTitle>
            <CardDescription>{subtitle}</CardDescription>
        </div>
    </div>;
}

def EmptyPanel(icon: any, title: str, text: str) -> JsxElement {
    return <Empty className="border border-dashed pt-8 pb-8">
        <EmptyHeader>
            <EmptyMedia variant="icon"><HugeiconsIcon icon={icon} strokeWidth={2} /></EmptyMedia>
            <EmptyTitle>{title}</EmptyTitle>
            <EmptyDescription>{text}</EmptyDescription>
        </EmptyHeader>
    </Empty>;
}

# ---------------- Map (placeholder) ----------------
# Plots locations inside a box using lat/lng. Swap for Leaflet/MapLibre later.
def:pub MapPanel(locations: list[LocationView], region: str) -> JsxElement {
    min_lat = 999.0; max_lat = -999.0; min_lng = 999.0; max_lng = -999.0;
    for loc in locations {
        min_lat = min(min_lat, loc.latitude); max_lat = max(max_lat, loc.latitude);
        min_lng = min(min_lng, loc.longitude); max_lng = max(max_lng, loc.longitude);
    }
    lat_span = max(max_lat - min_lat, 0.001);
    lng_span = max(max_lng - min_lng, 0.001);

    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={MapsLocation01Icon} title="Incident map" subtitle={region or "Locations linked to media"} /></CardHeader>
        <CardContent>
            {<EmptyPanel icon={MapsLocation01Icon} title="No locations yet" text="Media with a location will appear on the map." /> if len(locations) == 0 else
            <div className="relative h-64 overflow-hidden rounded-md border bg-[radial-gradient(circle_at_1px_1px,var(--border)_1px,transparent_0)] bg-[size:18px_18px] bg-muted/40">
                <div className="pointer-events-none absolute left-0 right-0 top-1/2 h-10 -translate-y-1/2 -rotate-6 bg-primary/10" />
                <span className="absolute bottom-2 left-3 text-xs text-muted-foreground">{"Bhote Koshi river (schematic)"}</span>
                {for loc in locations {
                    <div key={loc.name} className="absolute flex -translate-x-1/2 -translate-y-full flex-col items-center gap-1"
                        style={{"left": str(15 + 70 * (loc.longitude - min_lng) / lng_span) + "%", "top": str(80 - 60 * (loc.latitude - min_lat) / lat_span) + "%"}}>
                        <span className="whitespace-nowrap rounded-md border bg-card pt-0.5 pb-0.5 pl-2 pr-2 text-xs font-medium shadow-sm">{loc.name}</span>
                        <HugeiconsIcon icon={Location01Icon} strokeWidth={2} className="size-5 text-primary" />
                    </div>
                }}
            </div>}
        </CardContent>
    </Card>;
}

# ---------------- Full-bleed map (left side of the dashboard) ----------------
# Fills its parent. Placeholder: plots lat/lng in a box. Swap for Leaflet/MapLibre later.
def:pub MapCanvas(locations: list[LocationView], region: str) -> JsxElement {
    min_lat = 999.0; max_lat = -999.0; min_lng = 999.0; max_lng = -999.0;
    for loc in locations {
        min_lat = min(min_lat, loc.latitude); max_lat = max(max_lat, loc.latitude);
        min_lng = min(min_lng, loc.longitude); max_lng = max(max_lng, loc.longitude);
    }
    lat_span = max(max_lat - min_lat, 0.001);
    lng_span = max(max_lng - min_lng, 0.001);

    return <div className="relative h-full w-full overflow-hidden bg-muted/30 bg-[radial-gradient(circle_at_1px_1px,var(--border)_1px,transparent_0)] bg-[size:22px_22px]">
        <div className="pointer-events-none absolute -left-10 -right-10 top-1/2 h-16 -translate-y-1/2 -rotate-6 bg-primary/10" />
        <span className="absolute bottom-3 left-4 text-xs text-muted-foreground">{(region or "Map") + " - Bhote Koshi river (schematic)"}</span>
        {len(locations) == 0 and <div className="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground">{"No locations yet"}</div>}
        {for loc in locations {
            <div key={loc.name} className="absolute flex -translate-x-1/2 -translate-y-full flex-col items-center gap-1"
                style={{"left": str(20 + 60 * (loc.longitude - min_lng) / lng_span) + "%", "top": str(75 - 50 * (loc.latitude - min_lat) / lat_span) + "%"}}>
                <span className="whitespace-nowrap rounded-md border bg-card pt-0.5 pb-0.5 pl-2 pr-2 text-xs font-medium shadow-sm">{loc.name}</span>
                <HugeiconsIcon icon={Location01Icon} strokeWidth={2} className="size-5 text-primary" />
            </div>
        }}
    </div>;
}

# ---------------- People ----------------
def:pub PeoplePanel(
    people: list[PersonView],
    duplicates: list[DuplicateCandidate],
    selectedId: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={UserMultipleIcon} title="People" subtitle="Status comes from claims, not a single field" /></CardHeader>
        <CardContent className="flex flex-col gap-2">
            {len(people) == 0 and <EmptyPanel icon={UserMultipleIcon} title="No people yet" text="Reset the demo to seed Maya Gurung." />}
            {for p in people {
                <button key={p.id} type="button" onClick={lambda { onSelect(p.id); }}
                    className={cn("flex w-full items-center justify-between gap-3 rounded-md border pt-2.5 pb-2.5 pl-3 pr-3 text-left transition-colors hover:bg-muted/60",
                        "border-primary bg-primary/5" if p.id == selectedId else "")}>
                    <div className="flex flex-col">
                        <span className="text-sm font-medium">{p.name}</span>
                        <span className="text-xs text-muted-foreground">{"Age " + str(p.age) + " - " + str(len(p.claims)) + (" claim" if len(p.claims) == 1 else " claims")}</span>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                        <Badge variant="outline" className={status_class(p.latest_status)}>{p.latest_status}</Badge>
                        {p.has_conflict and <span className="text-[11px] font-medium text-amber-700 dark:text-amber-300">{"Conflicting claims"}</span>}
                    </div>
                </button>
            }}
            {for d in duplicates {
                <div key={d.person_a_id + d.person_b_id} className="flex flex-col gap-1.5 rounded-md border border-dashed bg-muted/40 pt-2.5 pb-2.5 pl-3 pr-3">
                    <div className="flex items-center gap-2 text-xs font-medium">
                        <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} className="size-4 text-primary" />
                        <span>{"Potential duplicate (" + d.confidence + ")"}</span>
                    </div>
                    <span className="text-sm">{d.person_a + " / " + d.person_b}</span>
                    <span className="text-xs text-muted-foreground">{", ".join(d.reasons)}</span>
                    <span className="text-[11px] text-muted-foreground">{"Not merged. Needs human confirmation."}</span>
                </div>
            }}
        </CardContent>
    </Card>;
}

# ---------------- Claims + provenance ----------------
def:pub ClaimsPanel(person: PersonView | None) -> JsxElement {
    if person == None {
        return <Card className="shadow-sm"><CardContent>
            <EmptyPanel icon={Activity01Icon} title="Pick a person" text="Select someone to see every claim and who made it." />
        </CardContent></Card>;
    }
    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={Activity01Icon} title={"Claims about " + person.name} subtitle="Every claim keeps its source. Nothing is overwritten." /></CardHeader>
        <CardContent className="flex flex-col gap-3">
            {person.has_conflict and <Alert className="border-amber-500/40 bg-amber-500/10">
                <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} />
                <AlertTitle>{"Conflicting or updated status information detected"}</AlertTitle>
                <AlertDescription>{"Both claims are kept below with their sources and timestamps. The newest is at the bottom."}</AlertDescription>
            </Alert>}
            {len(person.claims) == 0 and <EmptyPanel icon={Activity01Icon} title="No claims" text="No source has said anything about this person yet." />}
            <ol className="relative flex flex-col gap-3 border-l pl-5">
                {for c in person.claims {
                    <li key={c.id} className="relative animate-in fade-in slide-in-from-bottom-1 duration-500">
                        <span className="absolute -left-[26px] top-3 size-2.5 rounded-full bg-primary ring-4 ring-background" />
                        <div className="flex flex-col gap-1.5 rounded-md border bg-card pt-3 pb-3 pl-3 pr-3">
                            <div className="flex flex-wrap items-center justify-between gap-2">
                                <Badge variant="outline" className={status_class(c.claim_type)}>{c.claim_type}</Badge>
                                <span className="text-xs tabular-nums text-muted-foreground">{short_time(c.timestamp)}</span>
                            </div>
                            <span className="text-sm">{c.value}</span>
                            <span className="text-xs text-muted-foreground">
                                {"Asserted by "}<span className="font-medium text-foreground">{c.source_name}</span>{" (" + c.source_type + ")"}
                            </span>
                            {c.notes and <span className="text-xs text-muted-foreground">{c.notes}</span>}
                            {len(c.supporting_media) > 0 and <span className="text-xs text-muted-foreground">{"Supported by: " + ", ".join(c.supporting_media)}</span>}
                        </div>
                    </li>
                }}
            </ol>
        </CardContent>
    </Card>;
}

# ---------------- Media + verification signals ----------------
def:pub EvidencePanel(media: list[MediaView]) -> JsxElement {
    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={Image01Icon} title="Media and evidence" subtitle="Independent signals. No single truth score." /></CardHeader>
        <CardContent>
            {<EmptyPanel icon={Image01Icon} title="No media yet" text="Media added to the incident appears here with its signals." /> if len(media) == 0 else
            <div className="grid gap-3 md:grid-cols-3">
                {for m in media {
                    <div key={m.id} className="flex flex-col gap-2 rounded-md border bg-card pt-3 pb-3 pl-3 pr-3">
                        <div className="flex items-start justify-between gap-2">
                            <span className="text-sm font-medium">{m.description}</span>
                            <Badge variant="secondary">{m.media_type}</Badge>
                        </div>
                        <span className="text-xs text-muted-foreground">{m.location_name + " - " + short_time(m.captured_at)}</span>
                        {m.earliest_known_copy and <span className="text-xs font-medium text-primary">{"Earliest known copy (not proof of origin)"}</span>}
                        {len(m.depicts) > 0 and <span className="text-xs text-muted-foreground">{"Depicts: " + ", ".join(m.depicts)}</span>}
                        <div className="flex flex-col divide-y rounded-md border">
                            {for s in m.signals {
                                <div key={s.signal_type} title={s.explanation} className="flex items-center justify-between gap-2 pt-1.5 pb-1.5 pl-2 pr-2 text-xs">
                                    <span className="text-muted-foreground">{s.signal_type.replace("_", " ").lower()}</span>
                                    <span className={cn("text-right font-medium", confidence_class(s.confidence))}>{s.value}</span>
                                </div>
                            }}
                        </div>
                    </div>
                }}
            </div>}
        </CardContent>
    </Card>;
}

# ---------------- Alerts + agent activity ----------------
def:pub AlertsPanel(alerts: list[AlertView], activity: list[ActivityView]) -> JsxElement {
    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={Notification01Icon} title="Alerts and agent activity" subtitle="What the walkers did, newest first" /></CardHeader>
        <CardContent className="flex flex-col gap-4">
            {len(alerts) == 0 and <EmptyPanel icon={Notification01Icon} title="No alerts yet" text="Click Add Hospital Update to let WatchWalker react." />}
            {for a in alerts {
                <Alert key={a.created_at + a.message} className="border-primary/40 bg-primary/5 animate-in fade-in slide-in-from-bottom-2 duration-500">
                    <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} />
                    <AlertTitle>{"Alert for " + a.subscriber_name}</AlertTitle>
                    <AlertDescription>{a.message}</AlertDescription>
                </Alert>
            }}
            <div className="flex flex-col gap-2">
                <span className="text-xs font-medium text-muted-foreground">{"Agent activity"}</span>
                <div className="flex max-h-64 flex-col gap-1.5 overflow-y-auto">
                    {for e in activity {
                        <div key={e.created_at + e.message} className="flex items-start gap-2 text-xs">
                            <Badge variant="outline" className="shrink-0 font-mono text-[10px]">{e.walker_name}</Badge>
                            <span className="text-muted-foreground">{e.message}</span>
                        </div>
                    }}
                </div>
            </div>
        </CardContent>
    </Card>;
}

# ---------------- Graph view ----------------
def GraphNode(kind: str, label: str, tone: str = "") -> JsxElement {
    return <div className={cn("inline-flex items-center gap-2 rounded-md border bg-card pt-1 pb-1 pl-2 pr-2 text-xs shadow-sm", tone)}>
        <span className="font-mono text-[10px] uppercase text-muted-foreground">{kind}</span>
        <span className="font-medium">{label}</span>
    </div>;
}

def EdgeLabel(name: str) -> JsxElement {
    return <span className="font-mono text-[10px] text-muted-foreground">{"-" + name + "->"}</span>;
}

def:pub GraphTreePanel(incidentName: str, person: PersonView | None) -> JsxElement {
    if person == None {
        return <Card className="shadow-sm"><CardContent>
            <EmptyPanel icon={GitBranchIcon} title="Nothing to draw" text="Select a person to see their part of the graph." />
        </CardContent></Card>;
    }
    return <Card className="shadow-sm">
        <CardHeader><PanelTitle icon={GitBranchIcon} title="Trace graph" subtitle="The nodes and edges the walkers traverse" /></CardHeader>
        <CardContent>
            <div className="flex flex-col gap-2 overflow-x-auto">
                <GraphNode kind="Incident" label={incidentName} />
                <div className="ml-4 flex flex-col gap-2 border-l pl-4">
                    <div className="flex flex-wrap items-center gap-2"><EdgeLabel name="Involves" /><GraphNode kind="Person" label={person.name} tone="border-primary" /></div>
                    <div className="ml-4 flex flex-col gap-2 border-l pl-4">
                        {for c in person.claims {
                            <div key={c.id} className="flex flex-wrap items-center gap-2">
                                <span className="font-mono text-[10px] text-muted-foreground">{"<-About-"}</span>
                                <GraphNode kind="Claim" label={c.claim_type} tone={status_class(c.claim_type)} />
                                <span className="font-mono text-[10px] text-muted-foreground">{"<-Asserts-"}</span>
                                <GraphNode kind="Source" label={c.source_name} />
                            </div>
                        }}
                        {for s in person.subscriptions {
                            <div key={s.subscriber_name} className="flex flex-wrap items-center gap-2">
                                <EdgeLabel name="HasSubscription" />
                                <GraphNode kind="Subscription" label={s.subscriber_name} />
                                <EdgeLabel name="Receives" />
                                <GraphNode kind="Alert" label={str(s.alert_count) + (" alert" if s.alert_count == 1 else " alerts")} tone={"border-primary bg-primary/5" if s.alert_count > 0 else ""} />
                            </div>
                        }}
                    </div>
                </div>
            </div>
        </CardContent>
    </Card>;
}
