"""Graph tab diagram (Miguel): the incident graph drawn as records and links.

Draws f"snapshot.graph", the same GraphSnapshot the record list and inspector
read (built by the Jac traversal in features/graph/services.jac). Positions come
from layout_graph and are view data only. Clicking a record selects it in the
inspector; the selected record and its direct links stay bright. Dashed links
are derived or candidate relationships, never stored edges.
"""
import from ...lib.utils { cn }
import from .graph_helpers { kind_title, kind_order, kind_fill, edge_stroke }
import from .graph_layout { layout_graph, neighborhood }
sv import from .services { GraphSnapshot, GraphNodeView }

def:pub GraphCanvas(
    graph: GraphSnapshot, selectedId: str, onSelect: Callable[[str], None]
) -> JsxElement {
    has positions: dict[str, list[float]] = {};

    width = 900.0;
    height = 520.0;
    # Lay out again only when the set of records or links changes.
    signature = ",".join([n.id for n in graph.nodes]) + "|" + str(len(graph.edges));
    can with [signature] entry {
        positions = layout_graph(graph.nodes, graph.edges, width, height);
    }

    crowded = len(graph.nodes) > 80;
    focus = neighborhood(graph.edges, selectedId);
    kind_by_id: dict[str, str] = {};
    for n in graph.nodes { kind_by_id[n.id] = n.kind; }
    present = [k for k in kind_order() if len([n for n in graph.nodes if n.kind == k]) > 0];

    def radius(kind: str) -> float {
        base = 11.0 if kind == "Incident" else 8.0 if kind == "Person" else 6.0 if kind == "Claim" else 5.0;
        return base * 0.7 if crowded else base;
    }
    # Crowded graphs (the capped corpus) only label the selected neighbourhood.
    def show_label(n: GraphNodeView) -> bool {
        if n.id in focus { return True; }
        return not crowded and n.kind in ["Incident", "Person"];
    }
    def short_label(text: str) -> str {
        return text if len(text) <= 24 else text[:23] + "…";
    }

    return <figure className="flex flex-col gap-2">
        <div className="overflow-hidden rounded-lg border border-border bg-card">
            <svg viewBox="0 0 900 520" role="img" className="block h-auto w-full"
                aria-label={"Diagram of " + str(len(graph.nodes)) + " records and " + str(len(graph.edges)) + " links. Use the record list below for keyboard access."}>
                <defs>
                    <marker id="trace-graph-arrow" viewBox="0 0 10 10" refX="10" refY="5"
                        markerWidth="6" markerHeight="6" orient="auto-start-reverse">
                        <path d="M0,0 L10,5 L0,10 z" className="fill-muted-foreground" />
                    </marker>
                </defs>
                {for e in graph.edges {
                    if e.from_id in positions and e.to_id in positions {
                        a: list[float] = positions[e.from_id];
                        b: list[float] = positions[e.to_id];
                        ddx = b[0] - a[0];
                        ddy = b[1] - a[1];
                        dist = Math.max(Math.sqrt(ddx * ddx + ddy * ddy), 1.0);
                        # Stop the line at the target circle so the arrowhead shows.
                        trim = radius(kind_by_id[e.to_id]) + 2;
                        touching = e.from_id == selectedId or e.to_id == selectedId;
                        <line key={e.id} x1={a[0]} y1={a[1]}
                            x2={b[0] - ddx / dist * trim} y2={b[1] - ddy / dist * trim}
                            className={cn(edge_stroke(e.status), "" if touching or selectedId == "" else "opacity-20")}
                            strokeWidth={2 if touching else 1}
                            strokeDasharray={"5 4" if e.derived else None}
                            markerEnd="url(#trace-graph-arrow)" />
                    }
                }}
                {for n in graph.nodes {
                    if n.id in positions {
                        p: list[float] = positions[n.id];
                        r = radius(n.kind);
                        <g key={n.id} onClick={lambda { onSelect(n.id); }}
                            className={cn("cursor-pointer", "" if n.id in focus or selectedId == "" else "opacity-30")}>
                            <title>{n.kind + ": " + n.label}</title>
                            <circle cx={p[0]} cy={p[1]} r={r} className={cn(kind_fill(n.kind), "stroke-card")} strokeWidth={1.5} />
                            {n.id == selectedId and <circle cx={p[0]} cy={p[1]} r={r + 4} className="fill-none stroke-ring" strokeWidth={2} />}
                            {show_label(n) and <text x={p[0]} y={p[1] - r - 5} textAnchor="middle" fontSize={11}
                                className="fill-foreground stroke-card" strokeWidth={3} paintOrder="stroke">{short_label(n.label)}</text>}
                        </g>
                    }
                }}
            </svg>
        </div>
        <figcaption className="flex flex-col gap-2 text-xs text-muted-foreground">
            <p>{"Drawn from the same Jac graph traversal as the record list. Click a record to inspect it. Arrows follow the stored edge direction; dashed links are computed on read, not stored."}</p>
            <ul className="flex flex-wrap gap-x-3 gap-y-1.5" aria-label="Diagram legend">
                {for k in present {
                    <li key={k} className="inline-flex items-center gap-1.5">
                        <svg viewBox="0 0 10 10" className="size-2.5" aria-hidden="true"><circle cx={5} cy={5} r={5} className={kind_fill(k)} /></svg>
                        {kind_title(k)}
                    </li>
                }}
                <li className="inline-flex items-center gap-1.5">
                    <svg viewBox="0 0 20 4" className="h-1 w-5" aria-hidden="true"><line x1={0} y1={2} x2={20} y2={2} className="stroke-muted-foreground" strokeWidth={2} /></svg>
                    {"Stored edge"}
                </li>
                <li className="inline-flex items-center gap-1.5">
                    <svg viewBox="0 0 20 4" className="h-1 w-5" aria-hidden="true"><line x1={0} y1={2} x2={20} y2={2} className="stroke-primary" strokeWidth={2} strokeDasharray="4 3" /></svg>
                    {"Derived / candidate (not stored)"}
                </li>
            </ul>
        </figcaption>
    </figure>;
}
