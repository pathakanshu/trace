"""Shared dashboard shell. Anshu integrates changes here.

Feature owners work in features/<tab>/, not this file. Tabs share one snapshot
and an onRefresh callback; each tab owns its own input/selection state.
Panels remain mounted so switching tabs does not discard drafts or filters.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Refresh01Icon, Hospital01Icon, UserSearch01Icon, Notification01Icon,
    Settings01Icon, Cancel01Icon
}
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from .shared.ActivityPanel { AlertsPanel }
import from .shared.InvestigationPanel { InvestigationPanel }
import from ..features.map.MapTab { MapTab }
import from ..features.people.PeopleTab { PeopleTab }
import from ..features.media.MediaTab { MediaTab }
import from ..features.organizations.OrganizationsTab { OrganizationsTab }
import from ..features.graph.GraphTab { GraphTab }
sv import from ..services.trace {
    DashboardSnapshot, get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve
}

glob USE_DARK_THEME: bool = True;
glob DASHBOARD_TABS: list[str] = ["Map", "People", "Media", "Organizations", "Graph"];

def:pub TraceDashboard() -> JsxElement {
    has snapshot: DashboardSnapshot | None = None,
        loading: bool = True,
        busy: str = "",
        error: str = "",
        notice: str = "",
        activeTab: str = "Map",
        showDemo: bool = False;

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
    def handleTabKey(event: any, index: int) -> None;

    if loading and snapshot == None {
        return <div className="min-h-svh bg-background p-6" role="status" aria-label="Loading incident">
            <div className="flex flex-col gap-4">
                <Skeleton className="h-12 w-72" />
                <Skeleton className="h-[70svh] w-full" />
            </div>
        </div>;
    }
    snap = snapshot;
    hospital_added = snap.hospital_update_added if snap else False;

    return <div className="flex min-h-svh flex-col bg-background text-foreground">
        <header className="border-b border-border">
            <div className="flex flex-wrap items-center justify-between gap-3 pt-2.5 pb-2.5 pl-4 pr-4 md:pl-6 md:pr-6">
                <span className="text-sm text-muted-foreground">{"One incident. Every trace."}</span>
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

        <div className="flex flex-col gap-4 border-b border-border px-4 pt-5 md:px-6">
            <div className="flex flex-wrap items-end justify-between gap-4">
                <div className="flex flex-col gap-1">
                    <h1 className="font-display text-5xl tracking-tight">{"Trace"}</h1>
                    <p className="text-sm text-muted-foreground">{"People, places, and evidence connected through their sources."}</p>
                </div>
                <div className="flex flex-col gap-1 md:text-right">
                    <span className="text-xs text-muted-foreground">{"Current incident"}</span>
                    <span className="font-display text-xl">{snap.incident_name if snap else "Unavailable"}</span>
                    <span className="text-xs text-muted-foreground">{snap.incident_region if snap else ""}</span>
                </div>
            </div>
            <div role="tablist" aria-label="Incident views" className="flex gap-1 overflow-x-auto">
                {for i in range(len(DASHBOARD_TABS)) {
                    <button key={DASHBOARD_TABS[i]} id={"tab-" + DASHBOARD_TABS[i]}
                        type="button" role="tab"
                        aria-selected={activeTab == DASHBOARD_TABS[i]}
                        aria-controls={"panel-" + DASHBOARD_TABS[i]}
                        tabIndex={0 if activeTab == DASHBOARD_TABS[i] else -1}
                        onClick={lambda { activeTab = DASHBOARD_TABS[i]; }}
                        onKeyDown={lambda (event: any) { handleTabKey(event, i); }}
                        className={"shrink-0 border-b-2 px-4 py-3 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring " +
                            ("border-primary text-primary" if activeTab == DASHBOARD_TABS[i] else "border-transparent text-muted-foreground hover:bg-accent hover:text-foreground")}>
                        {DASHBOARD_TABS[i]}
                    </button>
                }}
            </div>
        </div>

        {error and <div role="alert" className="mx-4 mt-4 flex items-center justify-between gap-3 rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive md:mx-6">
            <span>{error}</span>
            <Button variant="outline" size="sm" onClick={loadDashboard}>{"Try again"}</Button>
        </div>}
        {notice and <p role="status" className="mx-4 mt-4 border-l-2 border-primary pl-3 text-sm text-muted-foreground md:mx-6">{notice}</p>}

        {snap and <div className="grid flex-1 xl:grid-cols-[minmax(0,1fr)_320px]">
            <main className="min-w-0 p-4 md:p-6">
                <div id="panel-Map" role="tabpanel" aria-labelledby="tab-Map" tabIndex={0} hidden={activeTab != "Map"}>
                    <MapTab snapshot={snap} onRefresh={loadDashboard} active={activeTab == "Map"} />
                </div>
                <div id="panel-People" role="tabpanel" aria-labelledby="tab-People" tabIndex={0} hidden={activeTab != "People"}>
                    <PeopleTab snapshot={snap} onRefresh={loadDashboard} />
                    <InvestigationPanel snapshot={snap} />
                </div>
                <div id="panel-Media" role="tabpanel" aria-labelledby="tab-Media" tabIndex={0} hidden={activeTab != "Media"}>
                    <MediaTab snapshot={snap} onRefresh={loadDashboard} />
                </div>
                <div id="panel-Organizations" role="tabpanel" aria-labelledby="tab-Organizations" tabIndex={0} hidden={activeTab != "Organizations"}>
                    <OrganizationsTab snapshot={snap} onRefresh={loadDashboard} />
                </div>
                <div id="panel-Graph" role="tabpanel" aria-labelledby="tab-Graph" tabIndex={0} hidden={activeTab != "Graph"}>
                    <GraphTab snapshot={snap} onRefresh={loadDashboard} />
                </div>
            </main>
            <aside aria-label="Incident notifications and activity" className="min-w-0 border-t border-border bg-card p-4 md:p-6 xl:border-l xl:border-t-0">
                <AlertsPanel alerts={snap.alerts} activity={snap.activity} />
            </aside>
        </div>}
        <footer className="mt-auto flex flex-wrap justify-between gap-2 border-t border-border px-4 py-3 text-xs text-muted-foreground md:px-6">
            <span>{"Demo with made-up people. Reports can be wrong: confirm with the source."}</span>
            <span>{"Built with Jac for JacHacks UMich"}</span>
        </footer>
    </div>;
}
