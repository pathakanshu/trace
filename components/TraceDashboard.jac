"""TraceDashboard - the one screen of the starter.

This component OWNS all page state (f"has" fields = React state). It loads a
DashboardSnapshot from the server and hands pieces to the panels.
Button handler bodies live in TraceDashboard.impl.jac (paired by file name).

f"sv import" = "these live on the server"; calling them makes an HTTP request.
Always f"await" them.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Radar01Icon, Refresh01Icon, Hospital01Icon, UserSearch01Icon, Notification01Icon,
    UserMultipleIcon, Activity01Icon, Alert02Icon
}
import from .ui.button { Button }
import from .ui.card { Card, CardContent }
import from .ui.skeleton { Skeleton }
import from .DashboardPanels {
    MapPanel, PeoplePanel, ClaimsPanel, EvidencePanel, AlertsPanel, GraphTreePanel
}
sv import from ..services.trace {
    DashboardSnapshot, PersonView,
    get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve
}

def StatCard(label: str, value: int, icon: any, highlight: bool = False) -> JsxElement {
    return <Card className="shadow-sm" size="sm">
        <CardContent className="flex items-center justify-between gap-3">
            <div className="flex flex-col gap-1">
                <span className="text-xs text-muted-foreground">{label}</span>
                <span className={"text-2xl font-semibold tracking-tight tabular-nums " + ("text-amber-700 dark:text-amber-300" if highlight else "")}>{str(value)}</span>
            </div>
            <div className="flex size-9 items-center justify-center rounded-md bg-primary/10 text-primary">
                <HugeiconsIcon icon={icon} strokeWidth={2} className="size-4" />
            </div>
        </CardContent>
    </Card>;
}

def:pub TraceDashboard() -> JsxElement {
    has snapshot: DashboardSnapshot | None = None,
        loading: bool = True,
        busy: str = "",          # which button is running ("" = none)
        error: str = "",
        notice: str = "",
        selectedId: str = "";

    can with entry { loadDashboard(); }

    async def loadDashboard -> None;
    async def handleReset -> None;
    async def handleHospitalUpdate -> None;
    async def handleRunWatch -> None;
    async def handleRunResolve -> None;

    if loading and snapshot == None {
        return <div className="min-h-svh bg-muted/40 pt-6 pb-6 pl-4 pr-4 md:pl-8 md:pr-8">
            <div className="mx-auto flex max-w-7xl flex-col gap-4">
                <Skeleton className="h-14 w-full" />
                <div className="grid gap-4 sm:grid-cols-4"><Skeleton className="h-20" /><Skeleton className="h-20" /><Skeleton className="h-20" /><Skeleton className="h-20" /></div>
                <div className="grid gap-4 lg:grid-cols-3"><Skeleton className="h-72 lg:col-span-2" /><Skeleton className="h-72" /></div>
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
    hospital_added = snap.hospital_update_added if snap else False;

    return <div className="min-h-svh bg-muted/40">
        <header className="sticky top-0 z-20 border-b bg-background/85 backdrop-blur">
            <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 pt-3 pb-3 pl-4 pr-4 md:pl-8 md:pr-8">
                <div className="flex items-center gap-3">
                    <div className="flex size-9 items-center justify-center rounded-md bg-primary text-primary-foreground shadow-sm">
                        <HugeiconsIcon icon={Radar01Icon} strokeWidth={2} className="size-5" />
                    </div>
                    <div className="flex flex-col">
                        <span className="text-base font-semibold tracking-tight">{"Trace"}</span>
                        <span className="text-xs text-muted-foreground">{"One incident. Every trace."}</span>
                    </div>
                </div>
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
                    <Button size="sm" className="shadow-sm" disabled={busy != "" or hospital_added} onClick={handleHospitalUpdate}>
                        <HugeiconsIcon icon={Hospital01Icon} strokeWidth={2} />
                        {"Adding..." if busy == "hospital" else ("Hospital update added" if hospital_added else "Add hospital update")}
                    </Button>
                </div>
            </div>
        </header>

        <main className="mx-auto flex max-w-7xl flex-col gap-5 pt-6 pb-10 pl-4 pr-4 md:pl-8 md:pr-8 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-semibold tracking-tight">{snap.incident_name if snap else "Trace"}</h1>
                <p className="text-sm text-muted-foreground">{(snap.incident_description if snap else "") + " Region: " + (snap.incident_region if snap else "")}</p>
            </div>

            {error and <div className="flex items-center justify-between gap-3 rounded-md border border-destructive/40 bg-destructive/5 pt-2 pb-2 pl-3 pr-3 text-sm text-destructive">
                <span>{error}</span>
                <Button variant="outline" size="sm" onClick={loadDashboard}>{"Retry"}</Button>
            </div>}
            {notice and <div className="rounded-md border bg-card pt-2 pb-2 pl-3 pr-3 text-sm text-muted-foreground">{notice}</div>}

            <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
                <StatCard label="People" value={len(people)} icon={UserMultipleIcon} />
                <StatCard label="Claims" value={claim_count} icon={Activity01Icon} />
                <StatCard label="Conflicts" value={conflict_count} icon={Alert02Icon} highlight={conflict_count > 0} />
                <StatCard label="Alerts" value={len(snap.alerts) if snap else 0} icon={Notification01Icon} highlight={snap != None and len(snap.alerts) > 0} />
            </div>

            <div className="grid gap-4 lg:grid-cols-3">
                <div className="flex flex-col gap-4 lg:col-span-2">
                    <MapPanel locations={snap.locations if snap else []} region={snap.incident_region if snap else ""} />
                    <ClaimsPanel person={selected} />
                </div>
                <div className="flex flex-col gap-4">
                    <PeoplePanel
                        people={people}
                        duplicates={snap.duplicates if snap else []}
                        selectedId={selected.id if selected else ""}
                        onSelect={lambda (pid: str) { selectedId = pid; }}
                    />
                    <GraphTreePanel incidentName={snap.incident_name if snap else ""} person={selected} />
                </div>
            </div>

            <div className="grid gap-4 lg:grid-cols-3">
                <div className="lg:col-span-2"><EvidencePanel media={snap.media if snap else []} /></div>
                <AlertsPanel alerts={snap.alerts if snap else []} activity={snap.activity if snap else []} />
            </div>
        </main>
    </div>;
}
