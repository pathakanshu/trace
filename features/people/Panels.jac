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
