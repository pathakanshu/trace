"""Four real counts from the snapshot. No invented metrics."""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    UserMultipleIcon, Alert02Icon, UserSearch01Icon, CheckmarkCircle02Icon
}
import from ...lib.utils { cn }
sv import from ...services.trace { PersonView }
sv import from ...walkers.resolve { DuplicateCandidate }

def:pub StatTile(label: str, value: int, hint: str, icon: any, tone: str) -> JsxElement {
    return <div className="flex items-center gap-3 rounded-lg border border-border bg-card pt-3 pb-3 pl-3 pr-4 shadow-sm">
        <div className={cn("flex size-9 shrink-0 items-center justify-center rounded-lg", tone)}>
            <HugeiconsIcon icon={icon} strokeWidth={2} className="size-4" />
        </div>
        <div className="flex min-w-0 flex-col">
            <span className="text-xl font-semibold leading-tight tracking-tight tabular-nums">{str(value)}</span>
            <span className="truncate text-xs text-muted-foreground">{label}</span>
        </div>
        <span className="ml-auto hidden text-[11px] text-muted-foreground 2xl:inline">{hint}</span>
    </div>;
}

def:pub PeopleStats(people: list[PersonView], duplicates: list[DuplicateCandidate]) -> JsxElement {
    missing = len([p for p in people if p.latest_status == "MISSING"]);
    differ = len([p for p in people if p.has_conflict]);
    pending = len([d for d in duplicates if d.decision == "PENDING"]);
    reviewed = len(duplicates) - pending;
    return <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 animate-in fade-in slide-in-from-bottom-1 duration-500">
        <StatTile label="Latest report: missing" value={missing} hint="by report time"
            icon={UserMultipleIcon} tone="bg-accent text-primary" />
        <StatTile label="Reports disagree" value={differ} hint="all kept"
            icon={Alert02Icon} tone="bg-accent text-primary" />
        <StatTile label="Matches to review" value={pending} hint="human decision"
            icon={UserSearch01Icon} tone="bg-accent text-primary" />
        <StatTile label="Matches reviewed" value={reviewed} hint="with reviewer"
            icon={CheckmarkCircle02Icon} tone="bg-accent text-primary" />
    </div>;
}
