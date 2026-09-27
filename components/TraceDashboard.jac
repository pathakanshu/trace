"""Shared dashboard shell. Anshu integrates changes here.

Feature owners work in features/<tab>/, not this file. Tabs share one snapshot
and an onRefresh callback; each tab owns its own input/selection state.
Panels remain mounted so switching tabs does not discard drafts or filters.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Refresh01Icon, Hospital01Icon, UserSearch01Icon, Notification01Icon,
    Settings01Icon, Cancel01Icon, Database01Icon, Sun03Icon, Moon02Icon,
    MapsIcon, UserMultipleIcon, Image01Icon, Building03Icon, Share08Icon
}
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from .shared.ActivityPanel { AlertsPanel }
import from .shared.InvestigationPanel { InvestigationPanel }
import from .shared.Scale { CorpusTotals, is_corpus_snapshot, fmt_count }
import from .shared.StoryBar { StoryBar, story_tab }
import from .shared.AlertBanner { AlertBanner }
import from ..features.map.MapTab { MapTab }
import from ..features.people.PeopleTab { PeopleTab }
import from ..features.media.MediaTab { MediaTab }
import from ..features.organizations.OrganizationsTab { OrganizationsTab }
import from ..features.graph.GraphTab { GraphTab }
sv import from ..services.trace {
    DashboardSnapshot, IncidentOption, get_dashboard, reset_demo, add_hospital_update, run_watch,
    run_resolve, list_incidents, load_corpus
}

glob USE_DARK_THEME: bool = True;
glob DASHBOARD_TABS: list[str] = ["Map", "People", "Media", "Sources", "Graph"];
glob TAB_ICONS: list = [MapsIcon, UserMultipleIcon, Image01Icon, Building03Icon, Share08Icon];

# The dark class on <html> switches every colour token (see styles/trace-tokens.css).
def apply_theme(dark: bool) -> None {
    if dark { document.documentElement.classList.add("dark"); }
    else { document.documentElement.classList.remove("dark"); }
}

# Remembered per browser; storage can be blocked, so fall back to the default.
def saved_theme_is_dark(default_dark: bool) -> bool {
    try {
        saved = localStorage.getItem("trace-theme");
        if saved == "light" { return False; }
        if saved == "dark" { return True; }
    } except Exception {
        return default_dark;
    }
    return default_dark;
}

# Wait one render so a newly shown tab or panel exists before scrolling to it.
def scroll_to_later(element_id: str) -> None {
    setTimeout(lambda {
        target: any = document.getElementById(element_id);
        if target { target.scrollIntoView({"behavior": "smooth", "block": "start"}); }
    }, 150);
}

def:pub TraceDashboard() -> JsxElement {
    has snapshot: DashboardSnapshot | None = None,
        loading: bool = True,
        busy: str = "",
        error: str = "",
        notice: str = "",
        activeTab: str = "Map",
        showDemo: bool = False,
        mapFocusId: str = "", mapFocusRequest: int = 0,
        incidents: list[IncidentOption] = [], incidentId: str = "",
        darkMode: bool = USE_DARK_THEME,
        storyStep: int = 1, reviewRequest: int = 0, investigateRequest: int = 0, bannerId: str = "";

    can with entry {
        # Local copy: a state update is not readable until the next render.
        startDark = saved_theme_is_dark(USE_DARK_THEME);
        apply_theme(startDark);
        darkMode = startDark;
        loadStartup();
    }

    async def loadDashboard -> None;
    async def loadStartup -> None;
    async def loadIncidentSnapshot(targetId: str) -> None;
    async def loadIncidents -> None;
    async def handleSelectIncident(targetId: str) -> None;
    async def handleLoadCorpus -> None;
    async def handleReset -> None;
    async def handleHospitalUpdate -> None;
    async def handleRunWatch -> None;
    async def handleRunResolve -> None;
    def handleTabKey(event: any, index: int) -> None;
    def handleShowOnMap(claimId: str) -> None;
    def handleShowPersonOnMap(personId: str) -> None;
    def handleToggleTheme -> None;
    def handleStoryStep(step: int) -> None;
    async def handleStoryAction(step: int) -> None;

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
    corpus_view = is_corpus_snapshot(snap);
    has_corpus = len([i for i in incidents if i.kind == "corpus"]) > 0;
    banner_alerts = [a for a in snap.alerts if bannerId != "" and (a.id or a.created_at) == bannerId] if snap and not corpus_view else [];

    return <div className="flex min-h-svh flex-col bg-background text-foreground">
        <header className="border-b border-border">
            <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 md:px-6">
                <div className="flex min-w-0 items-center gap-4">
                    <div className="flex flex-col">
                        <h1 className="font-display text-3xl leading-none tracking-tight md:text-4xl">{"Trace"}</h1>
                        <span className="mt-1 text-xs text-muted-foreground">{"One incident. Every trace."}</span>
                    </div>
                    <span className="hidden h-10 w-px bg-border sm:block" aria-hidden="true" />
                    <div className="flex min-w-0 flex-col">
                        <span className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">{"Current incident"}</span>
                        <span className="break-words font-display text-lg leading-tight md:text-xl">{snap.incident_name if snap else "Unavailable"}</span>
                        <span className="text-xs text-muted-foreground">{snap.incident_region if snap else ""}</span>
                    </div>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                    {len(incidents) > 1 and <div role="group" aria-label="Choose an incident"
                        className="flex max-w-full flex-wrap items-center gap-1 rounded-md border border-border bg-card p-1">
                        {for opt in incidents {
                            <button key={opt.id} type="button"
                                aria-pressed={(opt.kind == "demo" and incidentId == "") or (opt.kind != "demo" and opt.id == incidentId)}
                                disabled={busy != ""}
                                onClick={lambda { handleSelectIncident("" if opt.kind == "demo" else opt.id); }}
                                className={"min-h-9 rounded px-3 py-1.5 text-left text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60 " +
                                    ("bg-primary text-primary-foreground" if (opt.kind == "demo" and incidentId == "") or (opt.kind != "demo" and opt.id == incidentId) else "text-muted-foreground hover:bg-accent hover:text-foreground")}>
                                {"Maya story (demo)" if opt.kind == "demo" else (opt.name + " - " + fmt_count(opt.record_count) + " records")}
                            </button>
                        }}
                        {busy == "switch" and <span role="status" className="px-2 text-xs text-muted-foreground">{"Loading incident..."}</span>}
                    </div>}
                    <Button variant="outline" size="icon-lg" onClick={handleToggleTheme}
                        aria-label={"Switch to light theme" if darkMode else "Switch to dark theme"}
                        title={"Switch to light theme" if darkMode else "Switch to dark theme"}>
                        <HugeiconsIcon icon={Sun03Icon if darkMode else Moon02Icon} strokeWidth={2} />
                    </Button>
                    <Button variant="ghost" size="sm" onClick={lambda { showDemo = not showDemo; }}>
                        <HugeiconsIcon icon={Cancel01Icon if showDemo else Settings01Icon} strokeWidth={2} />
                        {"Hide demo controls" if showDemo else "Demo controls"}
                    </Button>
                </div>
            </div>
            {showDemo and <div className="flex flex-wrap items-center gap-2 border-t border-border bg-muted/40 pt-2.5 pb-2.5 pl-4 pr-4 md:pl-6 md:pr-6">
                <span className="mr-2 text-xs text-muted-foreground">{"Presenter tools:"}</span>
                {not has_corpus and <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleLoadCorpus}>
                    <HugeiconsIcon icon={Database01Icon} strokeWidth={2} />
                    {"Loading corpus, this can take a minute..." if busy == "corpus" else "Load exercise corpus"}
                </Button>}
                {corpus_view and <span className="text-xs text-muted-foreground">{"The hospital report, update check, match search and reset act on the Maya story. Switch to it to use them."}</span>}
                {not corpus_view and <Button size="sm" disabled={busy != "" or hospital_added} onClick={handleHospitalUpdate}>
                    <HugeiconsIcon icon={Hospital01Icon} strokeWidth={2} />
                    {"Adding..." if busy == "hospital" else ("Hospital report added" if hospital_added else "Simulate hospital report")}
                </Button>}
                {not corpus_view and <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunWatch}>
                    <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} />{"Check for updates"}
                </Button>}
                {not corpus_view and <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleRunResolve}>
                    <HugeiconsIcon icon={UserSearch01Icon} strokeWidth={2} />{"Look for possible matches"}
                </Button>}
                {not corpus_view and <Button variant="outline" size="sm" disabled={busy != ""} onClick={handleReset}>
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} />{"Reset demo" if busy != "reset" else "Resetting..."}
                </Button>}
            </div>}
        </header>

        {snap and not corpus_view and <StoryBar step={storyStep} hospitalAdded={hospital_added} busy={busy}
            onStep={handleStoryStep} onAction={handleStoryAction}
            onShowGraph={lambda { activeTab = "Graph"; }} onReset={handleReset} />}

        {for a in banner_alerts {
            <AlertBanner key={a.id or a.created_at} alert={a} people={snap.people}
                onDismiss={lambda { bannerId = ""; }} onShowOnMap={handleShowPersonOnMap} />
        }}

        <div className="flex flex-col gap-4 border-b border-border px-4 pt-4 md:px-6">
            {corpus_view and <CorpusTotals snapshot={snap} />}
            <div role="tablist" aria-label="Incident views" className="flex gap-1 overflow-x-auto">
                {for i in range(len(DASHBOARD_TABS)) {
                    <button key={DASHBOARD_TABS[i]} id={"tab-" + DASHBOARD_TABS[i]}
                        type="button" role="tab"
                        aria-selected={activeTab == DASHBOARD_TABS[i]}
                        aria-controls={"panel-" + DASHBOARD_TABS[i]}
                        tabIndex={0 if activeTab == DASHBOARD_TABS[i] else -1}
                        onClick={lambda { activeTab = DASHBOARD_TABS[i]; }}
                        onKeyDown={lambda (event: any) { handleTabKey(event, i); }}
                        className={"inline-flex shrink-0 items-center gap-2 border-b-2 px-4 py-3 text-base font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring " +
                            ("border-primary text-primary" if activeTab == DASHBOARD_TABS[i] else "border-transparent text-muted-foreground hover:bg-accent hover:text-foreground")}>
                        <HugeiconsIcon icon={TAB_ICONS[i]} strokeWidth={2} className="size-4" aria-hidden="true" />
                        {DASHBOARD_TABS[i]}
                    </button>
                }}
            </div>
        </div>

        {error and <div role="alert" className="mx-4 mt-4 flex items-center justify-between gap-3 rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive md:mx-6">
            <span>{error}</span>
            <Button variant="outline" size="sm" onClick={loadDashboard}>{"Try again"}</Button>
        </div>}
        {notice and len(banner_alerts) == 0 and <p role="status" className="mx-4 mt-4 rounded-md border-l-4 border-primary bg-primary/5 px-3 py-2 text-sm md:mx-6">{notice}</p>}

        {snap and <div className="grid flex-1 xl:grid-cols-[minmax(0,1fr)_320px]">
            <main className="min-w-0 p-4 md:p-6">
                <div id="panel-Map" role="tabpanel" aria-labelledby="tab-Map" tabIndex={0} hidden={activeTab != "Map"}>
                    <MapTab key={"map-" + ("dark" if darkMode else "light")} snapshot={snap} onRefresh={loadDashboard} active={activeTab == "Map"}
                        focusLocationId={mapFocusId} focusRequest={mapFocusRequest} />
                </div>
                <div id="panel-People" role="tabpanel" aria-labelledby="tab-People" tabIndex={0} hidden={activeTab != "People"}>
                    <PeopleTab snapshot={snap} onRefresh={loadDashboard} onShowOnMap={handleShowOnMap} reviewRequest={reviewRequest} />
                    {not corpus_view and <InvestigationPanel snapshot={snap} onRefresh={loadDashboard} focusRequest={investigateRequest} />}
                </div>
                <div id="panel-Media" role="tabpanel" aria-labelledby="tab-Media" tabIndex={0} hidden={activeTab != "Media"}>
                    <MediaTab snapshot={snap} onRefresh={loadDashboard} />
                </div>
                <div id="panel-Sources" role="tabpanel" aria-labelledby="tab-Sources" tabIndex={0} hidden={activeTab != "Sources"}>
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
