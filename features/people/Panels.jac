"""Gabriel owns the people list and report timeline."""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    UserMultipleIcon, UserSearch01Icon, Activity01Icon, Alert02Icon, Clock01Icon
}
import from ...components.ui.badge { Badge }
import from ...components.shared.Display {
    SectionHeading, EmptyPanel, status_dot, status_badge, status_sentence,
    status_text, status_label, source_kind, friendly_time, plural
}
import from ...lib.utils { cn }
import from ...components.shared.PersonTimeline { PersonTimeline }
sv import from ...services.trace { PersonView }
sv import from ...walkers.resolve { DuplicateCandidate }

# AGENTS.md: "Displayed status is a cited summary" - always say who said it.
def status_source(p: PersonView) -> str {
    name = "";
    for c in p.claims {
        if c.claim_type == p.latest_status { name = c.source_name; }
    }
    return ("according to " + name) if name else "no one has reported a status yet";
}

def initials(name: str) -> str {
    parts = [t for t in name.replace(".", " ").split() if t];
    if len(parts) == 0 { return "?"; }
    if len(parts) == 1 { return parts[0][0].upper(); }
    return (parts[0][0] + parts[-1][0]).upper();
}

def soft_bg(claim_type: str) -> str {
    if claim_type == "MISSING" { return "bg-status-missing-soft text-status-missing"; }
    if claim_type == "FOUND_SAFE" { return "bg-status-safe-soft text-status-safe"; }
    if claim_type == "INJURED" { return "bg-status-warning-soft text-status-warning"; }
    return "bg-status-neutral-soft text-status-neutral";
}

def match_tone(decision: str) -> str {
    if decision == "CONFIRMED" { return "border-status-safe/40 bg-status-safe-soft"; }
    if decision == "REJECTED" { return "border-status-missing/30 bg-status-missing-soft"; }
    return "border-primary/30 bg-primary/5";
}

# ---------------- People list ----------------
def:pub PeoplePanel(
    people: list[PersonView],
    duplicates: list[DuplicateCandidate],
    selectedId: str,
    onSelect: Callable[[str], None],
    onReview: Callable[[str], None]
) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="People" subtitle="Select someone to see every report about them." />
        {len(people) == 0 and <EmptyPanel icon={UserMultipleIcon} title="No one listed yet" text="People appear here as soon as someone reports about them." />}
        <div className="flex flex-col gap-2">
            {for p in people {
                <button key={p.id} type="button" onClick={lambda { onSelect(p.id); }}
                    className={cn("relative flex w-full items-center gap-3 overflow-hidden rounded-lg border bg-card pt-3 pb-3 pl-4 pr-3 text-left shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md",
                        "border-primary ring-1 ring-primary/30" if p.id == selectedId else "border-border")}>
                    <span className={cn("absolute left-0 top-0 h-full w-1", status_dot(p.latest_status))} />
                    <span className={cn("flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-semibold", soft_bg(p.latest_status))}>{initials(p.name)}</span>
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
            <div key={d.person_a_id + d.person_b_id} className={cn("flex flex-col gap-2 rounded-lg border pt-3 pb-3 pl-3 pr-3", match_tone(d.decision))}>
                <div className="flex items-center gap-2 text-sm font-medium">
                    <span className="flex size-7 items-center justify-center rounded-md bg-primary/10 text-primary">
                        <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} className="size-4" />
                    </span>
                    <span>{"Could these be the same person?"}</span>
                    {d.proposed_by and <Badge variant="outline" className="ml-auto">{"Agent proposal"}</Badge>}
                </div>
                <div className="flex items-center gap-2">
                    <span className="flex size-7 items-center justify-center rounded-full bg-card text-[11px] font-semibold ring-1 ring-border">{initials(d.person_a)}</span>
                    <span className="text-sm font-medium">{d.person_a}</span>
                    <span className="text-xs text-muted-foreground">{"and"}</span>
                    <span className="flex size-7 items-center justify-center rounded-full bg-card text-[11px] font-semibold ring-1 ring-border">{initials(d.person_b)}</span>
                    <span className="text-sm font-medium">{d.person_b}</span>
                </div>
                <span className="text-xs text-muted-foreground">{"Why we think so: " + ", ".join(d.reasons)}</span>
                {d.decision == "PENDING" and <span className="text-xs italic text-muted-foreground">{"We keep them separate until someone who knows them confirms."}</span>}
                {d.decision != "PENDING" and <span className={cn("text-xs font-medium", "text-status-safe" if d.decision == "CONFIRMED" else "text-status-missing")}>
                    {("Confirmed same person" if d.decision == "CONFIRMED" else "Rejected: different people") + " by " + d.reviewer + ", " + friendly_time(d.decided_at)}
                </span>}
                <div>
                    <button type="button" onClick={lambda { onReview(d.person_a_id + "|" + d.person_b_id); }}
                        className="mt-1 inline-flex h-8 items-center rounded-md border border-border bg-card px-3 text-xs font-medium hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring outline-none">
                        {"Review match" if d.decision == "PENDING" else "View review"}
                    </button>
                </div>
            </div>
        }}
    </section>;
}

# ---------------- Reports about one person ----------------
def:pub ClaimsPanel(person: PersonView | None, mappedClaimIds: list[str] = [], onShowOnMap: Callable[[str], None] | None = None, incidentId: str = "") -> JsxElement {
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
                    <div className="relative flex flex-col gap-1.5 overflow-hidden rounded-lg border border-border bg-card pt-3 pb-3 pl-4 pr-3 shadow-sm">
                        <span className={cn("absolute left-0 top-0 h-full w-1", status_dot(c.claim_type))} />
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
                        {onShowOnMap and c.id in mappedClaimIds and <button type="button"
                            onClick={lambda { onShowOnMap(c.id); }}
                            className="self-start rounded px-1 py-2 text-xs text-primary underline underline-offset-4 focus-visible:ring-2 focus-visible:ring-ring">
                            {"Show on map"}
                        </button>}
                    </div>
                </li>
            }}
        </ol>
        {incidentId and <PersonTimeline incidentId={incidentId} personId={person.id} refreshToken={person} />}
    </section>;
}
