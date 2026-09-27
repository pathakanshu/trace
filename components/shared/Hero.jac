"""Opening band: what Trace does in one sentence, with live counts.

Every number is counted from the current dashboard snapshot, so the figures
change on stage as reports and alerts arrive. Coordinate changes with Anshu.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    UserMultipleIcon, File01Icon, Building03Icon, Notification01Icon
}
import from ...lib.utils { cn }
sv import from ...services.trace { DashboardSnapshot }

def:pub HeroStat(label: str, value: int, icon: any, tone: str, pulse: bool = False) -> JsxElement {
    return <div className="flex items-center gap-3 rounded-2xl border border-border/70 bg-card/80 px-4 py-3 shadow-sm backdrop-blur-sm">
        <span className={cn("relative inline-flex size-11 shrink-0 items-center justify-center rounded-xl", tone)}>
            {pulse and <span className="absolute inset-0 animate-ping rounded-xl bg-current opacity-20 motion-reduce:animate-none" aria-hidden="true" />}
            <HugeiconsIcon icon={icon} strokeWidth={2} className="relative size-5" />
        </span>
        <div className="flex flex-col">
            <span key={str(value)} className="font-display text-3xl leading-none tabular-nums animate-in fade-in zoom-in-95 duration-500 motion-reduce:animate-none">{str(value)}</span>
            <span className="mt-1 text-sm text-muted-foreground">{label}</span>
        </div>
    </div>;
}

def:pub Hero(snapshot: DashboardSnapshot) -> JsxElement {
    reports = 0;
    for p in snapshot.people { reports = reports + len(p.claims); }
    alerts = len(snapshot.alerts);
    return <section aria-label="About this demo" className="trace-hero border-b border-border">
        <div className="mx-auto grid max-w-[1600px] gap-6 px-4 py-7 md:px-8 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-center">
            <div className="flex max-w-3xl flex-col gap-3">
                <span className="inline-flex w-fit items-center gap-2 rounded-full border border-border bg-card/80 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    <span className="size-2 rounded-full bg-brand" aria-hidden="true" />
                    {snapshot.incident_name + " · fictional people"}
                </span>
                <h2 className="font-display text-4xl leading-[1.05] tracking-tight text-balance md:text-5xl">
                    {"After a flood, reports pour in. "}<span className="text-brand">{"Trace shows what's known, and who said it."}</span>
                </h2>
                <p className="max-w-2xl text-lg text-muted-foreground">
                    {"Every report stays with its source. When news changes, the people who care are told, and nothing is quietly overwritten."}
                </p>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:min-w-[26rem]">
                <HeroStat label="People reported" value={len(snapshot.people)} icon={UserMultipleIcon} tone="bg-accent text-primary" />
                <HeroStat label="Reports kept" value={reports} icon={File01Icon} tone="bg-brand-soft text-brand" />
                <HeroStat label="Organizations" value={len(snapshot.organizations)} icon={Building03Icon} tone="bg-story-match-soft text-story-match" />
                <HeroStat label="Alerts sent" value={alerts} icon={Notification01Icon}
                    tone="bg-status-safe-soft text-status-safe" pulse={alerts > 0} />
            </div>
        </div>
    </section>;
}
