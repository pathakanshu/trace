"""Browser-only layout for the Graph tab diagram. Pure math, no server calls.

layout_graph places every GraphNodeView from snapshot.graph on a 2-D canvas
with a small force-directed (Fruchterman-Reingold) layout:
  - linked records pull together, every pair of records pushes apart;
  - the start is deterministic (one ring per record kind, Incident in the
    centre), so the same graph always gets the same picture after a reset.

Explicit cl keeps it in the client bundle (see components/shared/Display.jac).
Math.* is the browser's JavaScript Math object.
"""
import from .graph_helpers { kind_order }
sv import from .services { GraphNodeView, GraphEdgeView }

# Returns {node_id: [x, y]} inside a width x height box.
cl def:pub layout_graph(
    nodes: list[GraphNodeView], edges: list[GraphEdgeView], width: float, height: float
) -> dict[str, list[float]] {
    positions: dict[str, list[float]] = {};
    count = len(nodes);
    if count == 0 {
        return positions;
    }
    margin = 24.0;
    cx = width / 2;
    cy = height / 2;

    # Deterministic start: one ring per record kind present, in kind_order().
    order = kind_order();
    rings: list[str] = [k for k in order if len([n for n in nodes if n.kind == k]) > 0];
    for n in nodes {
        if n.kind not in rings { rings.append(n.kind); }
    }
    step = Math.min(width, height) / 2 / (len(rings) + 1);
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

    # Force iterations. Fewer on the capped corpus graph (401 nodes) to stay fast.
    k = Math.sqrt(width * height / count) * 0.8;
    temperature = width / 8;
    iterations = 150 if count <= 150 else 60;
    for _ in range(iterations) {
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
        for link in links {
            a = link[0];
            b = link[1];
            ddx = xs[a] - xs[b];
            ddy = ys[a] - ys[b];
            pull = Math.sqrt(ddx * ddx + ddy * ddy) / k;
            dxs[a] -= ddx * pull;
            dys[a] -= ddy * pull;
            dxs[b] += ddx * pull;
            dys[b] += ddy * pull;
        }
        # Move each node at most `temperature`, with a light pull to the centre
        # so unlinked records stay on screen, then cool down.
        for i in range(count) {
            mx = dxs[i] - (xs[i] - cx) * 0.05;
            my = dys[i] - (ys[i] - cy) * 0.05;
            moved = Math.sqrt(mx * mx + my * my);
            if moved > 0 {
                limit = Math.min(moved, temperature);
                xs[i] = Math.max(margin, Math.min(width - margin, xs[i] + mx / moved * limit));
                ys[i] = Math.max(margin, Math.min(height - margin, ys[i] + my / moved * limit));
            }
        }
        temperature = temperature * 0.95;
    }

    for i in range(count) {
        positions[ids[i]] = [xs[i], ys[i]];
    }
    return positions;
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
