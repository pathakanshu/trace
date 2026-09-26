"""Map boundaries for the dashboard, from geometry.topo.json (project root).

The file holds Nepal's provinces, districts and constituencies as TopoJSON
(shared borders stored once as "arcs"). The browser draws it with MapLibre GL.

This module reads the file ONCE on the server, keeps only provinces +
districts, rounds coordinates to ~10 m and drops near-duplicate points so the
download is small, and caches the result. The client turns it into GeoJSON with
f"topojson-client" and hands that to MapLibre.

FUTURE: constituencies are still in the file; add "constituencies" to
LAYERS to ship them too. Point-in-district lookups also belong here.
"""

import json;
import os;

glob TOPO_FILE: str = "geometry.topo.json";
glob LAYERS: list[str] = ["provinces", "districts"];
glob DECIMALS: int = 4;           # 4 decimals of a degree = about 11 m
glob MIN_STEP: float = 0.003;     # skip points closer than ~300 m (fine at district zoom)

# Cache: filled on the first get_boundaries() call.
glob _cache: dict = {};

# Round one arc and drop points very close to the previous kept point.
# First and last points are always kept so shared borders still meet.
def _shrink_arc(arc: list[list[float]]) -> list[list[float]] {
    out: list[list[float]] = [];
    for i in range(len(arc)) {
        pt: list[float] = [round(arc[i][0], DECIMALS), round(arc[i][1], DECIMALS)];
        is_end = i == 0 or i == len(arc) - 1;
        if out and not is_end {
            last: list[float] = out[-1];
            dx: float = pt[0] - last[0];
            dy: float = pt[1] - last[1];
            if max(dx, -dx) + max(dy, -dy) < MIN_STEP {
                continue;
            }
        }
        out.append(pt);
    }
    return out;
}

def load_boundaries() -> dict {
    if not os.path.exists(TOPO_FILE) {
        return {"error": f"{TOPO_FILE} not found in {os.getcwd()}"};
    }
    with open(TOPO_FILE) as fh {
        topo = json.load(fh);
    }
    return {
        "type": "Topology",
        "bbox": topo.get("bbox"),
        "objects": {name: topo["objects"][name] for name in LAYERS},
        "arcs": [_shrink_arc(a) for a in topo["arcs"]]
    };
}

# Public endpoint: TopoJSON (provinces + districts) for the map.
def:pub get_boundaries() -> dict {
    if not _cache {
        _cache["topo"] = load_boundaries();
    }
    return _cache["topo"];
}
