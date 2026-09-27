"""Graph tab diagram (Miguel): the incident graph drawn as records and links.

Draws f"snapshot.graph", the same GraphSnapshot the record list and inspector
read (built by the Jac traversal in features/graph/services.jac), styled after
Jac's own /graph visualizer: coloured records, labels underneath, curved
arrows, and live physics. The layout animates into place; drag a record and
its neighbours spring around it. Pressing a record selects it in the inspector.
Dashed links are derived or candidate relationships, never stored edges.

The simulation lives in a Ref (graph_layout.jac) and one step runs per
animation frame until it settles, so nothing ticks while the graph is still.
"Jac's viewer" swaps in the runtime's own visualizer (JacGraphViewer.jac).
"""
import from ...components.ui.button { Button }
import from ...lib.utils { cn }
import from .graph_helpers { kind_title, kind_order, kind_fill, edge_stroke }
import from .graph_layout { start_layout, layout_step, layout_moving, layout_drag, layout_positions, neighborhood }
import from .JacGraphViewer { JacGraphViewer }
sv import from .services { GraphSnapshot, GraphNodeView }

def:pub GraphCanvas(
    graph: GraphSnapshot, selectedId: str, onSelect: Callable[[str], None]
) -> JsxElement {
    has frame: int = 0,
        runs: int = 0,
        physics: bool = True,
        view: str = "diagram",
        simRef: Ref[any] = Ref(None),
        rafRef: Ref[any] = Ref(None),
        physicsRef: Ref[bool] = Ref(True);

    width = 900.0;
    height = 640.0;
    # Keep the layout clear of the floating "Node types" legend (viewBox units).
    legend_strip = 190.0;
    crowded = len(graph.nodes) > 80;

    # One layout step per animation frame while records are still moving.
    def animate() -> None {
        rafRef.current = None;
        sim = simRef.current;
        if sim and physicsRef.current and layout_moving(sim) {
            layout_step(sim);
            frame = sim["steps"];
            rafRef.current = window.requestAnimationFrame(animate);
        }
    }
    def wake() -> None {
        if rafRef.current == None {
            rafRef.current = window.requestAnimationFrame(animate);
        }
    }

    # New records or links (or "Re-run layout"): start again from the rings.
    signature = ",".join([n.id for n in graph.nodes]) + "|" + str(len(graph.edges));
    can with (signature, runs) entry {
        sim = start_layout(graph.nodes, graph.edges, width, height, legend_strip);
        if not physicsRef.current {
            while layout_moving(sim) { layout_step(sim); }
        }
        simRef.current = sim;
        frame = frame + 1;
        wake();
    }
    can with [physics] entry {
        physicsRef.current = physics;
        if physics { wake(); }
    }
    can with exit {
        if rafRef.current { window.cancelAnimationFrame(rafRef.current); }
    }

    # Pointer position in diagram coordinates (the SVG viewBox).
    def svg_point(svg: any, e: any) -> list[float] {
        rect = svg.getBoundingClientRect();
        pointer_x: float = e.clientX;
        pointer_y: float = e.clientY;
        left: float = rect.left;
        top: float = rect.top;
        box_w: float = rect.width;
        box_h: float = rect.height;
        return [(pointer_x - left) / box_w * width, (pointer_y - top) / box_h * height];
    }
    def press(e: any, node_id: str) -> None {
        onSelect(node_id);
        sim = simRef.current;
        if not sim { return; }
        svg = e.currentTarget.ownerSVGElement;
        svg.setPointerCapture(e.pointerId);
        p = svg_point(svg, e);
        layout_drag(sim, sim["index"][node_id], p[0], p[1]);
        frame = sim["steps"];
        wake();
    }
    def drag(e: any) -> None {
        sim = simRef.current;
        if not sim or sim["drag"] < 0 { return; }
        p = svg_point(e.currentTarget, e);
        layout_drag(sim, sim["drag"], p[0], p[1]);
        frame = sim["steps"];
        wake();
    }
    def release(e: any) -> None {
        sim = simRef.current;
        if sim { sim["drag"] = -1; }
    }

    positions: dict[str, list[float]] = layout_positions(simRef.current) if simRef.current else {};
    focus = neighborhood(graph.edges, selectedId);
    kind_by_id: dict[str, str] = {};
    for n in graph.nodes { kind_by_id[n.id] = n.kind; }
    present = [k for k in kind_order() if len([n for n in graph.nodes if n.kind == k]) > 0];

    def radius(kind: str) -> float {
        base = 20.0 if kind == "Incident" else 16.0 if kind == "Person" else 13.0 if kind == "Claim" else 11.0;
        return base * 0.55 if crowded else base;
    }
    # Every record is labelled, like Jac's viewer; crowded graphs (the capped
    # corpus) only label the selected neighbourhood.
    def show_label(n: GraphNodeView) -> bool {
        return not crowded or n.id in focus;
    }
    def short_label(text: str) -> str {
        return text if len(text) <= 16 else text[:15] + "…";
    }
    def fmt(v: float) -> str {
        return str(Math.round(v * 10) / 10);
    }

    legend = <ul className="flex flex-col gap-1">
        {for k in present {
            <li key={k} className="flex items-center gap-2">
                <svg viewBox="0 0 10 10" className="size-3 shrink-0" aria-hidden="true"><circle cx={5} cy={5} r={5} className={kind_fill(k)} /></svg>
                {kind_title(k)}
            </li>
        }}
        <li className="flex items-center gap-2 pt-1">
            <svg viewBox="0 0 20 4" className="h-1 w-5 shrink-0" aria-hidden="true"><line x1={0} y1={2} x2={20} y2={2} className="stroke-muted-foreground" strokeWidth={2} /></svg>
            {"Stored edge"}
        </li>
        <li className="flex items-center gap-2">
            <svg viewBox="0 0 20 4" className="h-1 w-5 shrink-0" aria-hidden="true"><line x1={0} y1={2} x2={20} y2={2} className="stroke-primary" strokeWidth={2} strokeDasharray="4 3" /></svg>
            {"Derived / candidate"}
        </li>
    </ul>;

    return <figure className="flex flex-col gap-2">
        <div className="overflow-hidden rounded-lg border border-border bg-card">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border px-3 py-2">
                <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-semibold">{"Jac graph"}</span>
                    <span className="rounded-sm border border-primary/50 bg-primary/10 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-primary">
                        {"This incident" if view == "diagram" else "Whole server"}
                    </span>
                    {view == "diagram" and <span className="rounded-sm bg-muted px-2 py-0.5 text-xs text-muted-foreground">
                        {str(len(graph.nodes)) + " records, " + str(len(graph.edges)) + " links"}
                    </span>}
                </div>
                <div className="flex flex-wrap items-center gap-1.5">
                    {view == "diagram" and <Button variant="outline" size="sm" onClick={lambda { runs = runs + 1; }}>{"Re-run layout"}</Button>}
                    {view == "diagram" and <Button variant="outline" size="sm" aria-pressed={physics}
                        onClick={lambda { physics = not physics; }}>{"Physics on" if physics else "Physics off"}</Button>}
                    <Button variant={"default" if view == "diagram" else "outline"} size="sm" aria-pressed={view == "diagram"}
                        onClick={lambda { view = "diagram"; }}>{"Trace diagram"}</Button>
                    <Button variant={"default" if view == "jac" else "outline"} size="sm" aria-pressed={view == "jac"}
                        onClick={lambda { view = "jac"; }}>{"Jac's viewer"}</Button>
                </div>
            </div>
            {view == "jac" and <JacGraphViewer />}
            {view == "diagram" and <div className="relative">
                <div className="overflow-x-auto">
                    <svg viewBox="0 0 900 640" role="img" className="block h-auto w-full min-w-[40rem] select-none"
                        onPointerMove={drag} onPointerUp={release} onPointerCancel={release}
                        aria-label={"Diagram of " + str(len(graph.nodes)) + " records and " + str(len(graph.edges)) + " links. Use the record list below for keyboard access."}>
                        <defs>
                            <marker id="trace-graph-arrow" viewBox="0 0 10 10" refX="10" refY="5"
                                markerWidth="7" markerHeight="7" orient="auto-start-reverse">
                                <path d="M0,0 L10,5 L0,10 z" className="fill-muted-foreground" />
                            </marker>
                        </defs>
                        {for e in graph.edges {
                            if e.from_id in positions and e.to_id in positions {
                                a: list[float] = positions[e.from_id];
                                b: list[float] = positions[e.to_id];
                                ddx = b[0] - a[0];
                                ddy = b[1] - a[1];
                                # Bend each link a little, like Jac's viewer, so a pair
                                # of opposite links never draws on top of each other.
                                qx = (a[0] + b[0]) / 2 - ddy * 0.12;
                                qy = (a[1] + b[1]) / 2 + ddx * 0.12;
                                tx = b[0] - qx;
                                ty = b[1] - qy;
                                tlen = Math.max(Math.sqrt(tx * tx + ty * ty), 1.0);
                                # Stop at the target circle so the arrowhead shows.
                                trim = radius(kind_by_id[e.to_id]) + 3;
                                touching = e.from_id == selectedId or e.to_id == selectedId;
                                <path key={e.id} fill="none"
                                    d={"M " + fmt(a[0]) + " " + fmt(a[1]) + " Q " + fmt(qx) + " " + fmt(qy) + " " + fmt(b[0] - tx / tlen * trim) + " " + fmt(b[1] - ty / tlen * trim)}
                                    className={cn(edge_stroke(e.status), "opacity-100" if touching else "opacity-60")}
                                    strokeWidth={2.5 if touching else 1.2}
                                    strokeDasharray={"6 4" if e.derived else None}
                                    markerEnd="url(#trace-graph-arrow)" />
                            }
                        }}
                        {for n in graph.nodes {
                            if n.id in positions {
                                p: list[float] = positions[n.id];
                                r = radius(n.kind);
                                <g key={n.id} className="cursor-grab touch-none active:cursor-grabbing"
                                    onPointerDown={lambda (e: any) { press(e, n.id); }}>
                                    <title>{n.kind + ": " + n.label}</title>
                                    {n.id == selectedId and <circle cx={p[0]} cy={p[1]} r={r + 5} className="fill-none stroke-ring" strokeWidth={2.5} />}
                                    <circle cx={p[0]} cy={p[1]} r={r} className={cn(kind_fill(n.kind), "stroke-background/70")} strokeWidth={2} />
                                    {show_label(n) and <text x={p[0]} y={p[1] + r + 14} textAnchor="middle" fontSize={12}
                                        className={cn("fill-foreground stroke-card", "font-semibold" if n.id in focus else "")}
                                        strokeWidth={3} paintOrder="stroke">{short_label(n.label)}</text>}
                                </g>
                            }
                        }}
                    </svg>
                </div>
                <div className="pointer-events-none absolute bottom-3 left-3 hidden rounded-md border border-border bg-background/85 p-3 text-xs shadow-sm backdrop-blur-sm sm:block">
                    <p className="mb-1.5 font-semibold text-muted-foreground">{"Node types"}</p>
                    {legend}
                </div>
            </div>}
        </div>
        {view == "diagram" and <figcaption className="flex flex-col gap-2 text-xs text-muted-foreground">
            <p>{"Drawn from the same Jac graph traversal as the record list. Drag a record and its neighbours follow; press one to inspect it. Arrows follow the stored edge direction; dashed links are computed on read, not stored."}</p>
            <div className="sm:hidden">{legend}</div>
        </figcaption>}
    </figure>;
}
