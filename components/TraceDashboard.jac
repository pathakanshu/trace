"""TraceDashboard - the one screen of the starter, written for the public.

Who it is for: a family member or resident looking for news about someone.
So the top of the page is a search box and plain counts; the developer-only
buttons (reset, run walkers) live in a small "Demo controls" panel that is
collapsed by default.

Layout:
  top bar      : Trace wordmark + "Demo controls" toggle
  left / main  : title, search, counts, map, reports + connections, media
  right column : people list, notifications + recent updates

This component OWNS all page state (f"has" fields = React state). Handler
bodies live in TraceDashboard.impl.jac (paired by file name).

THEME: dark by default via the f"dark" class on <html>. All colours are tokens,
so light mode = flip USE_DARK_THEME (or add a toggle).
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Refresh01Icon, Hospital01Icon, UserSearch01Icon, Notification01Icon,
    Search01Icon, Settings01Icon, Cancel01Icon
}
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
    return <div className="flex flex-col gap-1 border-l border-border pl-4 first:border-l-0 first:pl-0">
        <span className={"font-display text-3xl leading-none tabular-nums " + ("text-status-warning" if highlight else "text-primary")}>{str(value)}</span>
        <span className="text-sm text-muted-foreground">{label}</span>
    </div>;
}

def:pub TraceDashboard() -> JsxElement {
    has snapshot: DashboardSnapshot | None = None,
        loading: bool = True,
        busy: str = "",          # which button is running ("" = none)
        error: str = "",
        notice: str = "",
        selectedId: str = "",
        query: str = "",         # search box text
        showDemo: bool = False;  # demo controls panel open?

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
                <div className="grid gap-6 lg:grid-cols-[1fr_400px]"><Skeleton className="h-[70svh]" /><Skeleton className="h-[70svh]" /></div>
            </div>
        </div>;
    }

    snap = snapshot;
    all_people: list[PersonView] = snap.people if snap else [];
    # Search: match any part of the name, ignoring case.
    q = query.strip().lower();
    people: list[PersonView] = [p for p in all_people if q == "" or q in p.name.lower()];

    selected: PersonView | None = None;
    for p in people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(people) > 0 { selected = people[0]; }

    missing_count = 0;
    safe_count = 0;
    differ_count = 0;
    for p in all_people {
        if p.latest_status == "MISSING" { missing_count += 1; }
        if p.latest_status == "FOUND_SAFE" { safe_count += 1; }
        if p.has_conflict { differ_count += 1; }
    }
    hospital_added = snap.hospital_update_added if snap else False;

    return <div className="flex min-h-svh flex-col bg-background text-foreground">
        {#* ---------- top bar ---------- *#}
        <header className="border-b border-border">
            <div className="flex flex-wrap items-center justify-between gap-3 pt-2.5 pb-2.5 pl-4 pr-4 md:pl-6 md:pr-6">
                <span className="text-sm text-muted-foreground">{"Find news about people affected by a disaster"}</span>
                <Button variant="ghost" size="sm" onClick={lambda { showDemo = not showDemo; }}>
                    <HugeiconsIcon icon={Cancel01Icon if showDemo else Settings01Icon} strokeWidth={2} />
                    {"Hide demo controls" if showDemo else "Demo controls"}
                </Button>
            </div>
            {showDemo and <div className="flex flex-wrap items-center gap-2 border-t border-border bg-muted/40 pt-2.5 pb-2.5 pl-4 pr-4 md:pl-6 md:pr-6">
                <span className="mr-2 text-xs text-muted-foreground">{"For the presentation only:"}</span>
                <Button size="sm" disabled={busy != "" or hospital_added} onClick={handleHospitalUpdate}>
                    <HugeiconsIcon icon={Hospital01Icon} strokeWidth={2} />
                    {"Adding..." if busy == "hospital" else ("Hospital report added" if hospital_added else "Simulate hospital report")}
                </Button>
                <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunWatch}>
                    <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} />{"Check for updates"}
                </Button>
                <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunResolve}>
                    <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} />{"Look for possible matches"}
                </Button>
                <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleReset}>
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} />{"Reset demo" if busy != "reset" else "Resetting..."}
                </Button>
            </div>}
        </header>

        <div className="grid flex-1 lg:grid-cols-[minmax(0,1fr)_400px]">
            {#* ---------- main column ---------- *#}
            <main className="flex min-w-0 flex-col gap-6 pt-5 pb-10 pl-4 pr-4 md:pl-6 md:pr-6 animate-in fade-in duration-500">
                <div className="flex flex-wrap items-end justify-between gap-6">
                    <div className="flex flex-col gap-1">
                        <h1 className="font-display text-5xl leading-none tracking-tight md:text-6xl">{"Trace"}</h1>
                        <span className="text-sm text-muted-foreground">{"Every report about a person, and who made it, in one place."}</span>
                    </div>
                    <div className="flex flex-col gap-1 md:text-right">
                        <span className="text-xs text-muted-foreground">{"Current disaster"}</span>
                        <span className="font-display text-xl">{snap.incident_name if snap else ""}</span>
                        <span className="text-xs text-muted-foreground">{snap.incident_region if snap else ""}</span>
                    </div>
                </div>

                {#* search: the first thing a worried relative needs *#}
                <label className="flex flex-col gap-1.5">
                    <span className="text-sm font-medium">{"Looking for someone?"}</span>
                    <div className="relative">
                        <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                        <input
                            type="search"
                            value={query}
                            onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                            placeholder="Type a name, for example Maya"
                            className="h-11 w-full rounded-md border border-input bg-card pl-9 pr-3 text-base outline-none transition-colors placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/40"
                        />
                    </div>
                    {q != "" and <span className="text-xs text-muted-foreground">
                        {("No one named \"" + query + "\" has been reported yet.") if len(people) == 0 else ("Showing " + str(len(people)) + " of " + str(len(all_people)) + " people")}
                    </span>}
                </label>

                {error and <div className="flex items-center justify-between gap-3 rounded-md border border-destructive/50 bg-destructive/10 pt-2 pb-2 pl-3 pr-3 text-sm text-destructive">
                    <span>{error}</span>
                    <Button variant="outline" size="sm" onClick={loadDashboard}>{"Try again"}</Button>
                </div>}
                {notice and <div className="border-l-2 border-primary pl-3 text-sm italic text-muted-foreground">{notice}</div>}

                <div className="flex flex-wrap gap-6">
                    <StatBlock label="people listed" value={len(all_people)} />
                    <StatBlock label="still reported missing" value={missing_count} highlight={missing_count > 0} />
                    <StatBlock label="reported safe" value={safe_count} />
                    <StatBlock label="with reports that differ" value={differ_count} highlight={differ_count > 0} />
                </div>

                <div className="h-[46svh] min-h-80">
                    <MapPanel locations={snap.locations if snap else []} people={people} />
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
            <span>{"Demo with made-up people. Reports can be wrong: always confirm with the organisation that made them."}</span>
            <span>{"Built with Jac for JacHacks UMich"}</span>
        </footer>
    </div>;
}
