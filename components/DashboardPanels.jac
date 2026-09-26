"""Dashboard panels - each one is a different VIEW over the same Trace graph.

Stateless: TraceDashboard fetches the snapshot and passes pieces in as props.

STYLING RULE: only theme tokens (bg-card, text-muted-foreground, border-border,
text-primary, text-status-safe, bg-map-surface, font-display ...). Colours are
defined once in styles/global.css + styles/trace-tokens.css for light AND dark,
so switching themes never requires touching this file.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    MapsLocation01Icon, UserMultipleIcon, Image01Icon, Notification01Icon,
    GitBranchIcon, Alert02Icon, UserSearch01Icon, Activity01Icon
}
import from .ui.badge { Badge }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from ..lib.utils { cn }
sv import from ..services.trace {
    PersonView, MediaView, LocationView, AlertView, ActivityView
}
sv import from ..walkers.resolve { DuplicateCandidate }

# ---------------- small helpers ----------------

# Token classes for a claim type. Status colours only mean real state.
def status_text(claim_type: str) -> str {
    if claim_type == "MISSING" { return "text-status-missing"; }
    if claim_type == "FOUND_SAFE" { return "text-status-safe"; }
    if claim_type == "INJURED" { return "text-status-warning"; }
    return "text-status-neutral";
}

def status_badge(claim_type: str) -> str {
    if claim_type == "MISSING" { return "bg-status-missing-soft text-status-missing border-status-missing/40"; }
    if claim_type == "FOUND_SAFE" { return "bg-status-safe-soft text-status-safe border-status-safe/40"; }
    if claim_type == "INJURED" { return "bg-status-warning-soft text-status-warning border-status-warning/40"; }
    return "bg-status-neutral-soft text-status-neutral border-border";
}

def status_dot(claim_type: str) -> str {
    if claim_type == "MISSING" { return "bg-status-missing"; }
    if claim_type == "FOUND_SAFE" { return "bg-status-safe"; }
    if claim_type == "INJURED" { return "bg-status-warning"; }
    return "bg-status-neutral";
}

def confidence_text(confidence: str) -> str {
    if confidence == "HIGH" { return "text-status-safe"; }
    if confidence == "MEDIUM" { return "text-status-warning"; }
    return "text-muted-foreground";
}

# AGENTS.md: "Displayed status is a cited summary". This finds WHO said the
# status we display (the most recent claim of that type).
def status_source(p: PersonView) -> str {
    name = "";
    for c in p.claims {
        if c.claim_type == p.latest_status { name = c.source_name; }
    }
    return ("per " + name) if name else "no status claim yet";
}

# "2026-09-21T09:15:00" -> "Sep 21, 09:15"
def short_time(iso: str) -> str {
    if len(iso) < 16 { return iso; }
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[int(iso[5:7]) - 1] + " " + str(int(iso[8:10])) + ", " + iso[11:16];
}

# Serif section heading, like "Your Watchlist" / "Leaderboard" in the reference.
def SectionHeading(title: str, subtitle: str = "") -> JsxElement {
    return <div className="flex flex-col gap-1">
        <h2 className="font-display text-2xl leading-tight tracking-tight">{title}</h2>
        {subtitle and <p className="text-xs text-muted-foreground">{subtitle}</p>}
    </div>;
}

def EmptyPanel(icon: any, title: str, text: str) -> JsxElement {
    return <Empty className="border border-dashed border-border pt-8 pb-8">
        <EmptyHeader>
            <EmptyMedia variant="icon"><HugeiconsIcon icon={icon} strokeWidth={2} /></EmptyMedia>
            <EmptyTitle>{title}</EmptyTitle>
            <EmptyDescription>{text}</EmptyDescription>
        </EmptyHeader>
    </Empty>;
}

# ---------------- Map (the main surface) ----------------
# Schematic map: pins placed from lat/lng inside the box. Each pin shows the
# people linked to that place and their latest status colour.
# FUTURE: swap for Leaflet/MapLibre; keep the same props.
def:pub MapPanel(locations: list[LocationView], media: list[MediaView], people: list[PersonView]) -> JsxElement {
    if len(locations) == 0 {
        return <div className="flex h-full min-h-80 items-center justify-center pl-6 pr-6">
            <EmptyPanel icon={MapsLocation01Icon} title="No locations yet" text="Media with a location will appear on the map." />
        </div>;
    }
    min_lat = 999.0; max_lat = -999.0; min_lng = 999.0; max_lng = -999.0;
    for loc in locations {
        min_lat = min(min_lat, loc.latitude); max_lat = max(max_lat, loc.latitude);
        min_lng = min(min_lng, loc.longitude); max_lng = max(max_lng, loc.longitude);
    }
    lat_span = max(max_lat - min_lat, 0.001);
    lng_span = max(max_lng - min_lng, 0.001);

    return <div className="relative h-full min-h-80 overflow-hidden rounded-md border border-border bg-map-surface bg-[radial-gradient(circle_at_1px_1px,var(--map-grid)_1px,transparent_0)] bg-[size:22px_22px]">
        {#* schematic terrain + river *#}
        <div className="pointer-events-none absolute left-[8%] right-[6%] top-[18%] bottom-[16%] rounded-[45%_55%_40%_60%] bg-map-land" />
        <div className="pointer-events-none absolute left-0 right-0 top-1/2 h-8 -translate-y-1/2 -rotate-[8deg] bg-map-water blur-[1px]" />
        <span className="absolute bottom-3 left-4 font-display text-sm italic text-muted-foreground">{"Bhote Koshi river (schematic)"}</span>
        {for loc in locations {
            <div key={loc.name} className="absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-1.5"
                style={{"left": str(18 + 64 * (loc.longitude - min_lng) / lng_span) + "%", "top": str(72 - 44 * (loc.latitude - min_lat) / lat_span) + "%"}}>
                <span className="relative flex size-4">
                    <span className="absolute inline-flex size-full animate-ping rounded-full bg-primary/50" />
                    <span className="relative inline-flex size-4 rounded-full border-2 border-background bg-primary" />
                </span>
                <div className="flex flex-col items-center gap-0.5 rounded-md border border-border bg-card/95 pt-1 pb-1 pl-2.5 pr-2.5 shadow-sm backdrop-blur">
                    <span className="whitespace-nowrap text-xs font-medium">{loc.name}</span>
                    <span className="whitespace-nowrap text-[10px] text-muted-foreground">
                        {str(len([m for m in media if m.location_name == loc.name])) + " media"}
                    </span>
                </div>
            </div>
        }}
        <div className="absolute right-3 top-3 flex flex-col gap-1.5 rounded-md border border-border bg-card/95 pt-2 pb-2 pl-3 pr-3 text-xs backdrop-blur">
            <span className="font-medium">{"Latest claimed status"}</span>
            {for p in people {
                <div key={p.id} className="flex items-center gap-2">
                    <span className={cn("size-2.5 rounded-full", status_dot(p.latest_status))} />
                    <span>{p.name}</span>
                    <span className={cn("ml-auto pl-3 font-mono text-[10px]", status_text(p.latest_status))}>{p.latest_status}</span>
                    <span className="text-[10px] text-muted-foreground">{status_source(p)}</span>
                </div>
            }}
        </div>
    </div>;
}

# ---------------- People ("watchlist") ----------------
def:pub PeoplePanel(
    people: list[PersonView],
    duplicates: list[DuplicateCandidate],
    selectedId: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="People" subtitle="Status comes from claims, never a single field" />
        {len(people) == 0 and <EmptyPanel icon={UserMultipleIcon} title="No people yet" text="Reset the demo to seed Maya Gurung." />}
        <div className="flex flex-col divide-y divide-border border-t border-b border-border">
            {for p in people {
                <button key={p.id} type="button" onClick={lambda { onSelect(p.id); }}
                    className={cn("flex w-full items-center gap-3 pt-3 pb-3 pl-2 pr-2 text-left transition-colors hover:bg-accent",
                        "bg-accent" if p.id == selectedId else "")}>
                    <span className={cn("size-2.5 shrink-0 rounded-full", status_dot(p.latest_status))} />
                    <div className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate text-sm font-medium">{p.name}</span>
                        <span className="text-xs text-muted-foreground">{"Age " + str(p.age) + " - " + str(len(p.claims)) + (" claim" if len(p.claims) == 1 else " claims")}</span>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                        <Badge variant="outline" className={status_badge(p.latest_status)}>{p.latest_status}</Badge>
                        <span className="text-[10px] text-muted-foreground">{status_source(p)}</span>
                        {p.has_conflict and <span className="text-[11px] font-medium text-status-warning">{"Sources disagree"}</span>}
                    </div>
                </button>
            }}
        </div>
        {for d in duplicates {
            <div key={d.person_a_id + d.person_b_id} className="flex flex-col gap-1.5 rounded-md border border-dashed border-border bg-muted/50 pt-2.5 pb-2.5 pl-3 pr-3">
                <div className="flex items-center gap-2 text-xs font-medium">
                    <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Potential duplicate (" + d.confidence + ")"}</span>
                </div>
                <span className="text-sm">{d.person_a + " / " + d.person_b}</span>
                <span className="text-xs text-muted-foreground">{", ".join(d.reasons)}</span>
                <span className="text-[11px] italic text-muted-foreground">{"Not merged. Needs human confirmation."}</span>
            </div>
        }}
    </section>;
}

# ---------------- Claims + provenance ----------------
def:pub ClaimsPanel(person: PersonView | None) -> JsxElement {
    if person == None {
        return <EmptyPanel icon={Activity01Icon} title="Pick a person" text="Select someone to see every claim and who made it." />;
    }
    return <section className="flex flex-col gap-3">
        <SectionHeading title={"Claims about " + person.name} subtitle="Every claim keeps its source. Nothing is overwritten." />
        {person.has_conflict and <div className="flex items-start gap-3 rounded-md border border-status-warning/40 bg-status-warning-soft pt-3 pb-3 pl-3 pr-3">
            <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-status-warning" />
            <div className="flex flex-col gap-0.5">
                <span className="text-sm font-medium">{"Conflicting or updated status information detected"}</span>
                <span className="text-xs text-muted-foreground">{"Both claims are kept with their sources and times (newest last). A newer claim may be an update, not a contradiction; nothing is resolved automatically."}</span>
            </div>
        </div>}
        {len(person.claims) == 0 and <EmptyPanel icon={Activity01Icon} title="No claims" text="No source has said anything about this person yet." />}
        <ol className="relative flex flex-col gap-3 border-l border-border pl-5">
            {for c in person.claims {
                <li key={c.id} className="relative animate-in fade-in slide-in-from-bottom-1 duration-500">
                    <span className={cn("absolute -left-[26px] top-3.5 size-2.5 rounded-full ring-4 ring-background", status_dot(c.claim_type))} />
                    <div className="flex flex-col gap-1.5 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            <Badge variant="outline" className={status_badge(c.claim_type)}>{c.claim_type}</Badge>
                            <span className="font-mono text-xs tabular-nums text-muted-foreground">{short_time(c.timestamp)}</span>
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
    </section>;
}

# ---------------- Media + verification signals ----------------
def:pub EvidencePanel(media: list[MediaView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Media and evidence" subtitle="Independent signals. No single truth score." />
        {<EmptyPanel icon={Image01Icon} title="No media yet" text="Media added to the incident appears here with its signals." /> if len(media) == 0 else
        <div className="grid gap-3 md:grid-cols-3">
            {for m in media {
                <div key={m.id} className="flex flex-col gap-2 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3">
                    <div className="flex items-start justify-between gap-2">
                        <span className="text-sm font-medium">{m.description}</span>
                        <Badge variant="secondary">{m.media_type}</Badge>
                    </div>
                    <span className="text-xs text-muted-foreground">{m.location_name + " - " + short_time(m.captured_at)}</span>
                    {m.earliest_known_copy and <span className="text-xs font-medium text-primary">{"Earliest known copy (not proof of origin)"}</span>}
                    {len(m.depicts) > 0 and <span className="text-xs text-muted-foreground">{"Depicts: " + ", ".join(m.depicts)}</span>}
                    <div className="flex flex-col divide-y divide-border rounded-md border border-border">
                        {for s in m.signals {
                            <div key={s.signal_type} title={s.explanation} className="flex items-center justify-between gap-2 pt-1.5 pb-1.5 pl-2 pr-2 text-xs">
                                <span className="text-muted-foreground">{s.signal_type.replace("_", " ").lower()}</span>
                                <span className={cn("text-right font-medium", confidence_text(s.confidence))}>{s.value}</span>
                            </div>
                        }}
                    </div>
                </div>
            }}
        </div>}
    </section>;
}

# ---------------- Alerts + agent activity (the "leaderboard" slot) ----------------
def:pub AlertsPanel(alerts: list[AlertView], activity: list[ActivityView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Alerts" subtitle="Generated by WatchWalker for subscribers" />
        {len(alerts) == 0 and <EmptyPanel icon={Notification01Icon} title="No alerts yet" text="Click Add hospital update to let WatchWalker react." />}
        {for a in alerts {
            <div key={a.created_at + a.message} className="flex items-start gap-3 rounded-md border border-primary/40 bg-primary/10 pt-3 pb-3 pl-3 pr-3 animate-in fade-in slide-in-from-bottom-2 duration-500">
                <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">{"For " + a.subscriber_name}</span>
                    <span className="text-xs text-muted-foreground">{a.message}</span>
                </div>
            </div>
        }}
        <div className="flex flex-col gap-2 pt-2">
            <div className="flex items-baseline justify-between">
                <h3 className="font-display text-lg">{"Agent activity"}</h3>
                <span className="font-display text-xs italic text-muted-foreground">{"newest first"}</span>
            </div>
            <div className="flex max-h-72 flex-col divide-y divide-border overflow-y-auto border-t border-border">
                {for e in activity {
                    <div key={e.created_at + e.message} className="flex items-start gap-2 pt-2 pb-2 text-xs">
                        <span className="w-24 shrink-0 font-mono text-[10px] text-primary">{e.walker_name}</span>
                        <span className="text-muted-foreground">{e.message}</span>
                    </div>
                }}
            </div>
        </div>
    </section>;
}

# ---------------- Graph view ----------------
def GraphNode(kind: str, label: str, tone: str = "") -> JsxElement {
    return <div className={cn("inline-flex items-center gap-2 rounded-md border border-border bg-card pt-1 pb-1 pl-2 pr-2 text-xs shadow-sm", tone)}>
        <span className="font-mono text-[10px] uppercase text-muted-foreground">{kind}</span>
        <span className="font-medium">{label}</span>
    </div>;
}

def EdgeLabel(name: str) -> JsxElement {
    return <span className="font-mono text-[10px] text-muted-foreground">{name}</span>;
}

def:pub GraphTreePanel(incidentName: str, person: PersonView | None) -> JsxElement {
    if person == None {
        return <EmptyPanel icon={GitBranchIcon} title="Nothing to draw" text="Select a person to see their part of the graph." />;
    }
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Trace graph" subtitle="The nodes and edges the walkers traverse" />
        <div className="flex flex-col gap-2 overflow-x-auto">
            <GraphNode kind="Incident" label={incidentName} />
            <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                <div className="flex flex-wrap items-center gap-2"><EdgeLabel name="-Involves->" /><GraphNode kind="Person" label={person.name} tone="border-primary" /></div>
                <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                    {for c in person.claims {
                        <div key={c.id} className="flex flex-wrap items-center gap-2">
                            <EdgeLabel name="<-About-" />
                            <GraphNode kind="Claim" label={c.claim_type} tone={status_badge(c.claim_type)} />
                            <EdgeLabel name="<-Asserts-" />
                            <GraphNode kind="Source" label={c.source_name} />
                        </div>
                    }}
                    {for s in person.subscriptions {
                        <div key={s.subscriber_name} className="flex flex-wrap items-center gap-2">
                            <EdgeLabel name="-HasSubscription->" />
                            <GraphNode kind="Subscription" label={s.subscriber_name} />
                            <EdgeLabel name="-Receives->" />
                            <GraphNode kind="Alert" label={str(s.alert_count) + (" alert" if s.alert_count == 1 else " alerts")} tone={"border-primary bg-primary/10" if s.alert_count > 0 else ""} />
                        </div>
                    }}
                </div>
            </div>
        </div>
    </section>;
}
