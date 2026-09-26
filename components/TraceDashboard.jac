"""TraceDashboard - the one screen of the starter.

Layout (inspired by an election-tracker style):
  top bar      : Trace wordmark, incident, demo controls
  left / main  : big map surface, then claims + evidence below it
  right column : people ("watchlist"), graph view, alerts + agent activity

This component OWNS all page state (f"has" fields = React state). Button
handler bodies live in TraceDashboard.impl.jac (paired by file name).

THEME: dark mode is ON by default via the f"dark" class on <html> (set below).
All colours come from tokens (styles/global.css + styles/trace-tokens.css),
so a light-mode toggle later only needs to add/remove that one class.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Refresh01Icon, Hospital01Icon, UserSearch01Icon, Notification01Icon }
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from .DashboardPanels {
    MapPanel, PeoplePanel, ClaimsPanel, EvidencePanel, AlertsPanel, GraphTreePanel
}
sv import from ..services.trace {
    DashboardSnapshot, PersonView,
    get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve
}

# Change to False (or wire to a toggle) to get light mode. Nothing else changes.
glob USE_DARK_THEME: bool = True;

def StatBlock(label: str, value: int, highlight: bool = False) -> JsxElement {
    return <div className="flex flex-col gap-0.5 border-l border-border pl-4 first:border-l-0 first:pl-0">
        <span className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</span>
        <span className={"font-display text-3xl leading-none tabular-nums " + ("text-status-warning" if highlight else "text-primary")}>{str(value)}</span>
    </div>;
}

def:pub TraceDashboard() -> JsxElement {
    has snapshot: DashboardSnapshot | None = None,
        loading: bool = True,
        busy: str = "",          # which button is running ("" = none)
        error: str = "",
        notice: str = "",
        selectedId: str = "";

    can with entry {
        if USE_DARK_THEME { document.documentElement.classList.add("dark"); }
        else { document.documentElement.classList.remove("dark"); }
        loadDashboard();
    }

    async def loadDashboard -> None;
    async def handleReset -> None;
    async def handleHospitalUpdate -> None;
    async def handleRunWatch -> None;
    async def handleRunResolve -> None;

    if loading and snapshot == None {
        return <div className="min-h-svh bg-background pt-6 pb-6 pl-6 pr-6">
            <div className="flex flex-col gap-4">
                <Skeleton className="h-12 w-72" />
                <div className="grid gap-6 lg:grid-cols-[1fr_380px]"><Skeleton className="h-[70svh]" /><Skeleton className="h-[70svh]" /></div>
            </div>
        </div>;
    }

    snap = snapshot;
    people: list[PersonView] = snap.people if snap else [];
    selected: PersonView | None = None;
    for p in people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(people) > 0 { selected = people[0]; }

    claim_count = 0;
    conflict_count = 0;
    for p in people {
        claim_count += len(p.claims);
        if p.has_conflict { conflict_count += 1; }
    }
    alert_count = len(snap.alerts) if snap else 0;
    hospital_added = snap.hospital_update_added if snap else False;

    return <div className="flex min-h-svh flex-col bg-background text-foreground">
        {#* ---------- top bar ---------- *#}
        <header className="border-b border-border">
            <div className="flex flex-wrap items-center justify-between gap-3 pt-2.5 pb-2.5 pl-4 pr-4 md:pl-6 md:pr-6">
                <span className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">{"Disaster intelligence"}</span>
                <div className="flex flex-wrap items-center gap-2">
                    <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleReset}>
                        <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} />{"Reset demo" if busy != "reset" else "Resetting..."}
                    </Button>
                    <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunResolve}>
                        <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} />{"Run ResolveWalker"}
                    </Button>
                    <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunWatch}>
                        <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} />{"Run WatchWalker"}
                    </Button>
                    <Button size="sm" disabled={busy != "" or hospital_added} onClick={handleHospitalUpdate}>
                        <HugeiconsIcon icon={Hospital01Icon} strokeWidth={2} />
                        {"Adding..." if busy == "hospital" else ("Hospital update added" if hospital_added else "Add hospital update")}
                    </Button>
                </div>
            </div>
        </header>

        <div className="grid flex-1 lg:grid-cols-[minmax(0,1fr)_400px]">
            {#* ---------- main column ---------- *#}
            <main className="flex min-w-0 flex-col gap-6 pt-5 pb-10 pl-4 pr-4 md:pl-6 md:pr-6 animate-in fade-in duration-500">
                <div className="flex flex-wrap items-end justify-between gap-6">
                    <div className="flex flex-col gap-1">
                        <h1 className="font-display text-5xl leading-none tracking-tight md:text-6xl">{"Trace"}</h1>
                        <span className="text-sm text-muted-foreground">{"One incident. Every trace."}</span>
                    </div>
                    <div className="flex flex-col gap-1 md:text-right">
                        <span className="text-xs text-muted-foreground">{"Now tracking"}</span>
                        <span className="font-display text-xl">{snap.incident_name if snap else ""}</span>
                        <span className="text-xs text-muted-foreground">{snap.incident_region if snap else ""}</span>
                    </div>
                </div>

                {error and <div className="flex items-center justify-between gap-3 rounded-md border border-destructive/50 bg-destructive/10 pt-2 pb-2 pl-3 pr-3 text-sm text-destructive">
                    <span>{error}</span>
                    <Button variant="outline" size="sm" onClick={loadDashboard}>{"Retry"}</Button>
                </div>}
                {notice and <div className="border-l-2 border-primary pl-3 text-sm italic text-muted-foreground">{notice}</div>}

                <div className="flex flex-wrap gap-6">
                    <StatBlock label="People" value={len(people)} />
                    <StatBlock label="Claims" value={claim_count} />
                    <StatBlock label="Conflicts" value={conflict_count} highlight={conflict_count > 0} />
                    <StatBlock label="Alerts" value={alert_count} highlight={alert_count > 0} />
                </div>

                <div className="h-[46svh] min-h-80">
                    <MapPanel locations={snap.locations if snap else []} media={snap.media if snap else []} people={people} />
                </div>

                <div className="grid gap-8 xl:grid-cols-2">
                    <ClaimsPanel person={selected} />
                    <GraphTreePanel incidentName={snap.incident_name if snap else ""} person={selected} />
                </div>

                <EvidencePanel media={snap.media if snap else []} />
            </main>

            {#* ---------- right sidebar ---------- *#}
            <aside className="flex flex-col gap-8 border-t border-border bg-card pt-5 pb-10 pl-4 pr-4 md:pl-6 md:pr-6 lg:border-t-0 lg:border-l">
                <PeoplePanel
                    people={people}
                    duplicates={snap.duplicates if snap else []}
                    selectedId={selected.id if selected else ""}
                    onSelect={lambda (pid: str) { selectedId = pid; }}
                />
                <AlertsPanel alerts={snap.alerts if snap else []} activity={snap.activity if snap else []} />
            </aside>
        </div>

        <footer className="flex flex-wrap items-center justify-between gap-2 border-t border-border pt-2.5 pb-2.5 pl-4 pr-4 text-xs text-muted-foreground md:pl-6 md:pr-6">
            <span>{"Fictional demo data. Claims are evidence, not truth."}</span>
            <span>{"Built with Jac for JacHacks UMich"}</span>
        </footer>
    </div>;
}
