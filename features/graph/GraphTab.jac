"""Miguel's workspace: an inspector over the same stored graph every tab uses.

Everything renders from f"snapshot.graph" (a GraphSnapshot built by
features/graph/services.jac). Nothing is copied into local state except the
selected record's jid and a filter, so f"await onRefresh()" from any tab updates
this view in place.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Share08Icon, Alert02Icon, Refresh01Icon }
import from ...components.ui.button { Button }
import from ...components.shared.Display { SectionHeading, EmptyPanel }
import from ...lib.utils { cn }
import from .GraphTreePanel { RecordInspector, ProvenanceBadge }
import from .graph_helpers { kind_title, kind_order, short_id }
sv import from ...services.trace { DashboardSnapshot }
sv import from .services { GraphSnapshot, GraphNodeView }

def:pub GraphTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has selectedId: str = "",
        query: str = "",
        refreshing: bool = False,
        refreshError: str = "";

    async def handleRefresh -> None {
        refreshing = True;
        refreshError = "";
        try {
            await onRefresh();
        } except Exception as e {
            refreshError = "Could not reload the graph: " + str(e);
        }
        refreshing = False;
    }

    # f"graph" is added to DashboardSnapshot by Anshu; read it defensively until then.
    raw: any = snapshot;
    graph: GraphSnapshot | None = raw.graph if raw and raw.graph else None;

    if graph == None {
        return <div className="flex flex-col gap-5">
            <SectionHeading title="Graph" subtitle="Inspect the stored records behind every tab and how they connect." />
            <EmptyPanel icon={Alert02Icon} title="Graph projection not connected yet"
                text="The dashboard snapshot does not include a graph field yet. Once services/trace.jac sets snapshot.graph from build_graph_snapshot, records appear here." />
        </div>;
    }
    g: GraphSnapshot = graph;

    q = query.strip().lower();
    visible = [n for n in g.nodes if q == "" or q in n.label.lower() or q in n.kind.lower() or q in n.id.lower()];
    selected: GraphNodeView | None = None;
    for n in g.nodes {
        if n.id == selectedId { selected = n; }
    }
    if selected == None {
        for n in g.nodes {
            if selected == None and n.kind == "Claim" { selected = n; }
        }
    }
    stored_count = len([e for e in g.edges if not e.derived]);
    derived_count = len(g.edges) - stored_count;

    return <div className="flex flex-col gap-5">
        <div className="flex flex-wrap items-end justify-between gap-3">
            <SectionHeading title="Graph" subtitle="Inspect the stored records behind every tab, their real IDs, and the typed edges between them." />
            <Button variant="outline" size="sm" disabled={refreshing} onClick={handleRefresh}>
                <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} />{"Reloading..." if refreshing else "Reload graph"}
            </Button>
        </div>
        {refreshError and <div role="alert" className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">{refreshError}</div>}

        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-md border border-border bg-card p-3"><p className="text-xs text-muted-foreground">{"Records"}</p><p className="font-display text-2xl">{str(len(g.nodes))}</p></div>
            <div className="rounded-md border border-border bg-card p-3"><p className="text-xs text-muted-foreground">{"Stored edges"}</p><p className="font-display text-2xl">{str(stored_count)}</p></div>
            <div className="rounded-md border border-dashed border-border bg-card p-3"><p className="text-xs text-muted-foreground">{"Derived / candidate"}</p><p className="font-display text-2xl">{str(derived_count)}</p></div>
            <div className="rounded-md border border-border bg-card p-3"><p className="text-xs text-muted-foreground">{"Incident jid"}</p><p className="truncate font-mono text-sm pt-2" title={g.incident_id}>{short_id(g.incident_id)}</p></div>
        </div>

        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            <span>{"Legend:"}</span>
            {for b in ["stored", "confirmed", "candidate", "derived", "simulated", "walker ran"] { <ProvenanceBadge key={b} badge={b} /> }}
        </div>

        {if len(g.nodes) == 0 {
            <EmptyPanel icon={Share08Icon} title="No records in this incident" text="Seed or reset the demo to add reports, people and media." />
            skip;
        }}

        <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
            <nav aria-label="Graph records" className="flex flex-col gap-3 rounded-lg border border-border bg-card p-3">
                <label className="flex flex-col gap-1.5 text-sm">
                    <span className="font-medium">{"Find a record"}</span>
                    <input type="search" value={query}
                        onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                        placeholder="Name, type or jid"
                        className="h-10 w-full rounded-md border border-input bg-background px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                </label>
                <div className="flex max-h-[28rem] flex-col gap-3 overflow-y-auto lg:max-h-[70svh]">
                    {if len(visible) == 0 { <p className="p-2 text-sm text-muted-foreground">{"No records match."}</p> skip; }}
                    {for kind in kind_order() {
                        group = [n for n in visible if n.kind == kind];
                        if len(group) > 0 {
                            <section key={kind} className="flex flex-col gap-1">
                                <h3 className="px-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{kind_title(kind) + " (" + str(len(group)) + ")"}</h3>
                                <ul className="flex flex-col gap-1">
                                    {for n in group {
                                        <li key={n.id}>
                                            <button type="button" onClick={lambda { selectedId = n.id; }}
                                                aria-current={"true" if selected and selected.id == n.id else "false"}
                                                className={cn("flex w-full flex-col items-start gap-0.5 rounded-md px-2 py-1.5 text-left text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                                                    "bg-primary/15 text-foreground" if selected and selected.id == n.id else "hover:bg-accent")}>
                                                <span className="line-clamp-2 break-words">{n.label}</span>
                                                <span className="flex flex-wrap items-center gap-1.5 font-mono text-[11px] text-muted-foreground">
                                                    {short_id(n.id)}
                                                    {"simulated" in n.badges and <span className="text-status-warning">{"simulated"}</span>}
                                                </span>
                                            </button>
                                        </li>
                                    }}
                                </ul>
                            </section>
                        }
                    }}
                </div>
            </nav>
            <RecordInspector graph={g} record={selected} onSelect={lambda (rid: str) { selectedId = rid; }} />
        </div>
    </div>;
}
