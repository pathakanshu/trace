"""Browser-only layout for the Graph tab diagram. Pure math, no server calls.

A small force-directed (Fruchterman-Reingold) layout, written so the diagram
can animate it: start_layout builds the simulation, layout_step runs one
iteration per animation frame, and a dragged record stays under the pointer
while its neighbours spring around it.
  - linked records pull together, every pair of records pushes apart;
  - the start is deterministic (one ring per record kind, Incident in the
    centre), so the same graph always settles into the same picture.

Explicit cl keeps it in the client bundle (see components/shared/Display.jac).
Math.* is the browser's JavaScript Math object.
"""
cl import from .graph_helpers { kind_order }
sv import from .services { GraphNodeView, GraphEdgeView }

# The simulation is a plain dict so the diagram can keep it in a React ref and
# change it every frame without a re-render per field:
#   ids / index: record jid <-> array slot     xs / ys: positions
#   links: [from slot, to slot] per edge       k: ideal edge length
#   temperature: max move per step (cools)     steps: iterations so far
#   drag: slot pinned under the pointer, or -1
#   left: strip kept clear on the left (the diagram's legend sits there)
cl def:pub start_layout(
    nodes: list[GraphNodeView], edges: list[GraphEdgeView], width: float, height: float,
    left: float = 0.0
) -> dict[str, any] {
    count = len(nodes);
    cx = (width + left) / 2;
    cy = height / 2;
    # Deterministic start: one ring per record kind present, in kind_order().
    order = kind_order();
    rings: list[str] = [k for k in order if len([n for n in nodes if n.kind == k]) > 0];
    for n in nodes {
        if n.kind not in rings { rings.append(n.kind); }
    }
    step = Math.min(width - left, height) / 2 / (len(rings) + 1);
    xs: list[float] = [];
    ys: list[float] = [];
    index_of: dict[str, int] = {};
    for ring in range(len(rings)) {
        members = [n for n in nodes if n.kind == rings[ring]];
        radius = step * ring if ring > 0 or len(members) > 1 else 0.0;
        for j in range(len(members)) {
            angle = 2 * Math.PI * j / len(members) + ring * 0.7;
            index_of[members[j].id] = len(xs);
            xs.append(cx + radius * Math.cos(angle));
            ys.append(cy + radius * Math.sin(angle));
        }
    }
    ids: list[str] = ["" for i in range(count)];
    for n in nodes { ids[index_of[n.id]] = n.id; }
    links = [[index_of[e.from_id], index_of[e.to_id]] for e in edges
        if e.from_id in index_of and e.to_id in index_of and e.from_id != e.to_id];
    return {
        "ids": ids, "index": index_of, "xs": xs, "ys": ys, "links": links,
        "width": width, "height": height, "left": left,
        "k": Math.sqrt((width - left) * height / Math.max(count, 1)) * 0.45,
        "temperature": width / 8, "steps": 0, "drag": -1
    };
}

# One force iteration. Moves every record except the dragged one, then cools.
cl def:pub layout_step(sim: dict[str, any]) -> None {
    xs: list[float] = sim["xs"];
    ys: list[float] = sim["ys"];
    count = len(xs);
    k: float = sim["k"];
    width: float = sim["width"];
    height: float = sim["height"];
    left: float = sim["left"];
    cx = (width + left) / 2;
    cy = height / 2;
    margin = 32.0;
    dxs: list[float] = [0.0 for i in range(count)];
    dys: list[float] = [0.0 for i in range(count)];
    # Every pair repels with force k^2 / distance.
    for a in range(count) {
        for b in range(a + 1, count) {
            ddx = xs[a] - xs[b];
            ddy = ys[a] - ys[b];
            dist2 = ddx * ddx + ddy * ddy;
            if dist2 < 0.01 {
                ddx = 0.1 * (a - b);
                ddy = 0.1;
                dist2 = ddx * ddx + ddy * ddy;
            }
            push = k * k / dist2;
            dxs[a] += ddx * push;
            dys[a] += ddy * push;
            dxs[b] -= ddx * push;
            dys[b] -= ddy * push;
        }
    }
    # Every edge attracts with force distance^2 / k.
    for link in sim["links"] {
        a: int = link[0];
        b: int = link[1];
        ddx = xs[a] - xs[b];
        ddy = ys[a] - ys[b];
        pull = Math.sqrt(ddx * ddx + ddy * ddy) / k;
        dxs[a] -= ddx * pull;
        dys[a] -= ddy * pull;
        dxs[b] += ddx * pull;
        dys[b] += ddy * pull;
    }
    # Move each record at most `temperature`, with a pull to the centre so
    # unlinked records stay on screen.
    temperature: float = sim["temperature"];
    for i in range(count) {
        if i == sim["drag"] { continue; }
        mx = dxs[i] - (xs[i] - cx) * 0.6;
        my = dys[i] - (ys[i] - cy) * 0.6;
        moved = Math.sqrt(mx * mx + my * my);
        if moved > 0 {
            limit = Math.min(moved, temperature);
            xs[i] = Math.max(left + margin, Math.min(width - margin, xs[i] + mx / moved * limit));
            ys[i] = Math.max(margin, Math.min(height - margin, ys[i] + my / moved * limit));
        }
    }
    sim["temperature"] = temperature * 0.95;
    sim["steps"] = sim["steps"] + 1;
}

# True while records are still visibly moving (or one is being dragged).
cl def:pub layout_moving(sim: dict[str, any]) -> bool {
    return sim["temperature"] > 0.5 or sim["drag"] >= 0;
}

# Pin a record under the pointer and warm the layout so neighbours follow.
cl def:pub layout_drag(sim: dict[str, any], slot: int, x: float, y: float) -> None {
    xs: list[float] = sim["xs"];
    ys: list[float] = sim["ys"];
    margin = 32.0;
    xs[slot] = Math.max(sim["left"] + margin, Math.min(sim["width"] - margin, x));
    ys[slot] = Math.max(margin, Math.min(sim["height"] - margin, y));
    sim["drag"] = slot;
    sim["temperature"] = Math.max(sim["temperature"], 12.0);
    sim["steps"] = sim["steps"] + 1;
}

# Returns {node_id: [x, y]} for rendering.
cl def:pub layout_positions(sim: dict[str, any]) -> dict[str, list[float]] {
    positions: dict[str, list[float]] = {};
    ids: list[str] = sim["ids"];
    xs: list[float] = sim["xs"];
    ys: list[float] = sim["ys"];
    for i in range(len(ids)) {
        positions[ids[i]] = [xs[i], ys[i]];
    }
    return positions;
}

# Settled layout in one call (no animation). Fewer iterations on the capped
# corpus graph (401 nodes) to stay fast.
cl def:pub layout_graph(
    nodes: list[GraphNodeView], edges: list[GraphEdgeView], width: float, height: float
) -> dict[str, list[float]] {
    sim = start_layout(nodes, edges, width, height);
    iterations = 150 if len(nodes) <= 150 else 60;
    for _ in range(iterations) {
        layout_step(sim);
    }
    return layout_positions(sim);
}

# Ids of the selected record and every record one edge away from it.
cl def:pub neighborhood(edges: list[GraphEdgeView], node_id: str) -> list[str] {
    if node_id == "" {
        return [];
    }
    found: list[str] = [node_id];
    for e in edges {
        if e.from_id == node_id and e.to_id not in found { found.append(e.to_id); }
        if e.to_id == node_id and e.from_id not in found { found.append(e.from_id); }
    }
    return found;
}
