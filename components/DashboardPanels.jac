"""Dashboard panels - each one is a different VIEW over the same Trace graph.

Stateless: TraceDashboard fetches the snapshot and passes pieces in as props.

WRITING RULE: this screen is for families and residents, not developers.
Say "reported safe by Central Hospital", never "FOUND_SAFE claim asserted by
source". Graph words (claim, node, walker, provenance) stay in the code.

STYLING RULE: only theme tokens (bg-card, text-muted-foreground, text-primary,
text-status-safe, font-display ...). Colours live in styles/global.css +
styles/trace-tokens.css for light AND dark.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    UserMultipleIcon, Image01Icon, Notification01Icon, Alert02Icon,
    UserSearch01Icon, Activity01Icon, Clock01Icon, InformationCircleIcon
}
import from .ui.badge { Badge }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from ..lib.utils { cn }
import from .IncidentMap { IncidentMap }
sv import from ..services.trace {
    PersonView, MediaView, LocationView, AlertView, ActivityView
}
sv import from ..walkers.resolve { DuplicateCandidate }

# ---------------- plain-language helpers ----------------

# Short label for a status badge.
def status_label(claim_type: str) -> str {
    if claim_type == "MISSING" { return "Missing"; }
    if claim_type == "FOUND_SAFE" { return "Safe"; }
    if claim_type == "INJURED" { return "Injured"; }
    if claim_type == "DECEASED" { return "Deceased"; }
    if claim_type == "SEEN_AT_LOCATION" { return "Seen"; }
    return "No status yet";
}

# Sentence form: "Reported missing", "Reported safe", ...
def status_sentence(claim_type: str) -> str {
    if claim_type == "MISSING" { return "Reported missing"; }
    if claim_type == "FOUND_SAFE" { return "Reported safe"; }
    if claim_type == "INJURED" { return "Reported injured"; }
    if claim_type == "DECEASED" { return "Reported deceased"; }
    if claim_type == "SEEN_AT_LOCATION" { return "Reported seen"; }
    return "Report";
}

# "POLICE" -> "Police", "COMMUNITY" -> "Community member" ...
def source_kind(source_type: str) -> str {
    kinds = {"POLICE": "Police", "HOSPITAL": "Hospital", "COMMUNITY": "Community member", "NGO": "Aid group", "GOVERNMENT": "Government"};
    return kinds.get(source_type, "Source");
}

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

# Confidence as words a person trusts: how sure is this clue?
def confidence_label(confidence: str) -> str {
    if confidence == "HIGH" { return "Strong clue"; }
    if confidence == "MEDIUM" { return "Some support"; }
    if confidence == "NONE" { return "Not checked"; }
    return "Unclear";
}

def confidence_text(confidence: str) -> str {
    if confidence == "HIGH" { return "text-status-safe"; }
    if confidence == "MEDIUM" { return "text-status-warning"; }
    return "text-muted-foreground";
}

# Friendly names for each kind of media check.
def check_name(signal_type: str) -> str {
    names = {
        "EXIF_LOCATION": "Where it was taken",
        "COMMUNITY_GEOLOCATION": "Place identified by volunteers",
        "DUPLICATE_MATCH": "Posted elsewhere",
        "PROVENANCE": "Who made it",
        "SYNTHETIC_MEDIA": "AI-made or edited"
    };
    return names.get(signal_type, signal_type.replace("_", " ").lower());
}

# AGENTS.md: "Displayed status is a cited summary" - always say who said it.
def status_source(p: PersonView) -> str {
    name = "";
    for c in p.claims {
        if c.claim_type == p.latest_status { name = c.source_name; }
    }
    return ("according to " + name) if name else "no one has reported a status yet";
}

# "2026-09-21T09:15:00" -> "Sep 21, 9:15 AM"
def friendly_time(iso: str) -> str {
    if len(iso) < 16 { return iso; }
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    hour = int(iso[11:13]);
    suffix = "AM" if hour < 12 else "PM";
    hour12 = hour % 12;
    if hour12 == 0 { hour12 = 12; }
    return months[int(iso[5:7]) - 1] + " " + str(int(iso[8:10])) + ", " + str(hour12) + ":" + iso[14:16] + " " + suffix;
}

def plural(n: int, word: str) -> str {
    return str(n) + " " + word + ("" if n == 1 else "s");
}

def SectionHeading(title: str, subtitle: str = "") -> JsxElement {
    return <div className="flex flex-col gap-1">
        <h2 className="font-display text-2xl leading-tight tracking-tight">{title}</h2>
        {subtitle and <p className="text-sm text-muted-foreground">{subtitle}</p>}
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

# ---------------- Map ----------------
def:pub MapPanel(locations: list[LocationView], people: list[PersonView]) -> JsxElement {
    return <div className="relative h-full min-h-80">
        <IncidentMap locations={locations} />
        <div className="pointer-events-none absolute right-3 top-3 flex flex-col gap-1.5 rounded-md border border-border bg-card/95 pt-2 pb-2 pl-3 pr-3 text-xs backdrop-blur">
            <span className="font-medium">{"Latest news on each person"}</span>
            {for p in people {
                <div key={p.id} className="flex items-center gap-2">
                    <span className={cn("size-2.5 rounded-full", status_dot(p.latest_status))} />
                    <span>{p.name}</span>
                    <span className={cn("ml-auto pl-3 font-medium", status_text(p.latest_status))}>{status_label(p.latest_status)}</span>
                </div>
            }}
        </div>
        <span className="pointer-events-none absolute bottom-3 left-3 font-display text-sm italic text-muted-foreground">{"Shaded area: Sindhupalchok district, where the flood happened"}</span>
    </div>;
}

# ---------------- People list ----------------
def:pub PeoplePanel(
    people: list[PersonView],
    duplicates: list[DuplicateCandidate],
    selectedId: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="People" subtitle="Select someone to see every report about them." />
        {len(people) == 0 and <EmptyPanel icon={UserMultipleIcon} title="No one listed yet" text="People appear here as soon as someone reports about them." />}
        <div className="flex flex-col divide-y divide-border border-t border-b border-border">
            {for p in people {
                <button key={p.id} type="button" onClick={lambda { onSelect(p.id); }}
                    className={cn("flex w-full items-center gap-3 pt-3 pb-3 pl-2 pr-2 text-left transition-colors hover:bg-accent",
                        "bg-accent" if p.id == selectedId else "")}>
                    <span className={cn("size-2.5 shrink-0 rounded-full", status_dot(p.latest_status))} />
                    <div className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate text-sm font-medium">{p.name}</span>
                        <span className="text-xs text-muted-foreground">{"Age " + str(p.age) + " - " + plural(len(p.claims), "report")}</span>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                        <Badge variant="outline" className={status_badge(p.latest_status)}>{status_label(p.latest_status)}</Badge>
                        <span className="text-[11px] text-muted-foreground">{status_source(p)}</span>
                        {p.has_conflict and <span className="text-[11px] font-medium text-status-warning">{"Reports differ"}</span>}
                    </div>
                </button>
            }}
        </div>
        {for d in duplicates {
            <div key={d.person_a_id + d.person_b_id} className="flex flex-col gap-1.5 rounded-md border border-dashed border-border bg-muted/50 pt-3 pb-3 pl-3 pr-3">
                <div className="flex items-center gap-2 text-sm font-medium">
                    <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Could these be the same person?"}</span>
                </div>
                <span className="text-sm">{d.person_a + " and " + d.person_b}</span>
                <span className="text-xs text-muted-foreground">{"Why we think so: " + ", ".join(d.reasons)}</span>
                <span className="text-xs italic text-muted-foreground">{"We keep them separate until someone who knows them confirms."}</span>
            </div>
        }}
    </section>;
}

# ---------------- Reports about one person ----------------
def:pub ClaimsPanel(person: PersonView | None) -> JsxElement {
    if person == None {
        return <EmptyPanel icon={Activity01Icon} title="Choose a person" text="Select someone from the list to see who reported what, and when." />;
    }
    return <section className="flex flex-col gap-3">
        <SectionHeading title={"What we know about " + person.name} subtitle="Every report, oldest first, with who said it." />
        {person.has_conflict and <div className="flex items-start gap-3 rounded-md border border-status-warning/40 bg-status-warning-soft pt-3 pb-3 pl-3 pr-3">
            <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-status-warning" />
            <div className="flex flex-col gap-0.5">
                <span className="text-sm font-medium">{"The reports about " + person.name + " say different things"}</span>
                <span className="text-sm text-muted-foreground">{"The newest report is at the bottom. It may be an update, but we show every report so you can decide. Contact the source directly to confirm."}</span>
            </div>
        </div>}
        {len(person.claims) == 0 and <EmptyPanel icon={Activity01Icon} title="No reports yet" text="No one has shared information about this person yet." />}
        <ol className="relative flex flex-col gap-3 border-l border-border pl-5">
            {for c in person.claims {
                <li key={c.id} className="relative animate-in fade-in slide-in-from-bottom-1 duration-500">
                    <span className={cn("absolute -left-[26px] top-3.5 size-2.5 rounded-full ring-4 ring-background", status_dot(c.claim_type))} />
                    <div className="flex flex-col gap-1.5 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            <span className={cn("text-sm font-semibold", status_text(c.claim_type))}>{status_sentence(c.claim_type)}</span>
                            <span className="flex items-center gap-1 text-xs text-muted-foreground">
                                <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-3.5" />{friendly_time(c.timestamp)}
                            </span>
                        </div>
                        <span className="text-sm">{c.value}</span>
                        <span className="text-xs text-muted-foreground">
                            {"From "}<span className="font-medium text-foreground">{c.source_name}</span>{" (" + source_kind(c.source_type) + ")"}
                        </span>
                        {c.notes and <span className="text-xs text-muted-foreground">{c.notes}</span>}
                        {len(c.supporting_media) > 0 and <span className="text-xs text-muted-foreground">{"Related photo: " + ", ".join(c.supporting_media)}</span>}
                    </div>
                </li>
            }}
        </ol>
    </section>;
}

# ---------------- Photos and videos ----------------
def:pub EvidencePanel(media: list[MediaView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Photos and videos" subtitle="What we could and could not check about each one. None of these checks alone proves a file is real or fake." />
        {<EmptyPanel icon={Image01Icon} title="No photos or videos yet" text="Shared photos and videos from the area will appear here." /> if len(media) == 0 else
        <div className="grid gap-3 md:grid-cols-3">
            {for m in media {
                <div key={m.id} className="flex flex-col gap-2 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3">
                    <div className="flex items-start justify-between gap-2">
                        <span className="text-sm font-medium">{m.description}</span>
                        <Badge variant="secondary">{"Photo" if m.media_type == "image" else "Video"}</Badge>
                    </div>
                    <span className="text-xs text-muted-foreground">{m.location_name + " - " + friendly_time(m.captured_at)}</span>
                    {m.earliest_known_copy and <span className="text-xs font-medium text-primary">{"Earliest copy we found (may not be the original)"}</span>}
                    {len(m.depicts) > 0 and <span className="text-xs text-muted-foreground">{"May show: " + ", ".join(m.depicts)}</span>}
                    <div className="flex flex-col divide-y divide-border rounded-md border border-border">
                        {for s in m.signals {
                            <div key={s.signal_type} className="flex flex-col gap-0.5 pt-2 pb-2 pl-2.5 pr-2.5 text-xs">
                                <div className="flex items-center justify-between gap-2">
                                    <span className="font-medium">{check_name(s.signal_type)}</span>
                                    <span className={cn("shrink-0 text-right", confidence_text(s.confidence))}>{confidence_label(s.confidence)}</span>
                                </div>
                                <span className="text-foreground">{s.value}</span>
                                <span className="text-muted-foreground">{s.explanation}</span>
                            </div>
                        }}
                    </div>
                </div>
            }}
        </div>}
    </section>;
}

# ---------------- Notifications + recent updates ----------------
def:pub AlertsPanel(alerts: list[AlertView], activity: list[ActivityView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Notifications" subtitle="Sent to people following someone when new information arrives." />
        {len(alerts) == 0 and <EmptyPanel icon={Notification01Icon} title="No notifications yet" text="When a new report comes in about someone, their followers are notified here." />}
        {for a in alerts {
            <div key={a.created_at + a.message} className="flex items-start gap-3 rounded-md border border-primary/40 bg-primary/10 pt-3 pb-3 pl-3 pr-3 animate-in fade-in slide-in-from-bottom-2 duration-500">
                <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">{"Sent to " + a.subscriber_name}</span>
                    <span className="text-sm text-muted-foreground">{a.message}</span>
                    <span className="text-[11px] text-muted-foreground">{friendly_time(a.created_at)}</span>
                </div>
            </div>
        }}
        <div className="flex flex-col gap-2 pt-2">
            <div className="flex items-baseline justify-between">
                <h3 className="font-display text-lg">{"Recent updates"}</h3>
                <span className="text-xs text-muted-foreground">{"newest first"}</span>
            </div>
            {len(activity) == 0 and <span className="text-sm text-muted-foreground">{"Nothing has happened yet."}</span>}
            <div className="flex max-h-72 flex-col divide-y divide-border overflow-y-auto border-t border-border">
                {for e in activity {
                    <div key={e.created_at + e.message} className="flex flex-col gap-0.5 pt-2 pb-2 text-sm">
                        <span className="text-foreground">{e.message}</span>
                        <span className="text-[11px] text-muted-foreground">{friendly_time(e.created_at)}</span>
                    </div>
                }}
            </div>
        </div>
    </section>;
}

# ---------------- How it connects (the graph, in plain words) ----------------
def Step(label: str, detail: str, tone: str = "") -> JsxElement {
    return <div className={cn("inline-flex flex-col rounded-md border border-border bg-card pt-1.5 pb-1.5 pl-2.5 pr-2.5 shadow-sm", tone)}>
        <span className="text-[11px] text-muted-foreground">{label}</span>
        <span className="text-sm font-medium">{detail}</span>
    </div>;
}

def Arrow(text: str) -> JsxElement {
    return <span className="text-xs text-muted-foreground">{text}</span>;
}

def:pub GraphTreePanel(incidentName: str, person: PersonView | None) -> JsxElement {
    if person == None {
        return <EmptyPanel icon={InformationCircleIcon} title="Choose a person" text="Select someone to see how the information about them connects." />;
    }
    return <section className="flex flex-col gap-3">
        <SectionHeading title="How the information connects" subtitle="Who reported what about this person, and who is following them." />
        <div className="flex flex-col gap-2 overflow-x-auto">
            <Step label="Disaster" detail={incidentName} />
            <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                <div className="flex flex-wrap items-center gap-2"><Arrow text="affected" /><Step label="Person" detail={person.name} tone="border-primary" /></div>
                <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                    {for c in person.claims {
                        <div key={c.id} className="flex flex-wrap items-center gap-2">
                            <Step label={source_kind(c.source_type)} detail={c.source_name} />
                            <Arrow text="says" />
                            <Step label="Report" detail={status_sentence(c.claim_type)} tone={status_badge(c.claim_type)} />
                        </div>
                    }}
                    {for s in person.subscriptions {
                        <div key={s.subscriber_name} className="flex flex-wrap items-center gap-2">
                            <Step label="Following" detail={s.subscriber_name} />
                            <Arrow text="received" />
                            <Step label="Notifications" detail={str(s.alert_count)} tone={"border-primary bg-primary/10" if s.alert_count > 0 else ""} />
                        </div>
                    }}
                </div>
            </div>
        </div>
    </section>;
}
