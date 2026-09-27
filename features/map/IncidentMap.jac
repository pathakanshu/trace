"""IncidentMap - interactive map of Nepal drawn with MapLibre GL.

MapLibre is the open-source fork of Mapbox GL JS: same kind of API, but no
access token, so the demo keeps working offline.

What it draws:
  - district + province borders from geometry.topo.json (via get_boundaries)
  - current OSM river corridor and settlement labels, with district outline
  - one pin per Location node from the Trace graph

JS interop notes (see f"jac guide jac-cl-js-interop"):
  - f"new(maplibregl.Map, {...})" is how Jac calls a JS constructor.
  - The map object lives in a Ref so re-renders don't recreate it.
  - Colours are read from CSS variables, so the map follows the theme.
"""

import from "maplibre-gl" { Map as MapLibreMap, Marker, NavigationControl, AttributionControl }
import "maplibre-gl/dist/maplibre-gl.css";
import from "topojson-client" { feature }
import from ...lib.utils { cn }
import from .Status { linked_people, pin_status, pin_label, pin_dot }
sv import from ...services.geo { get_boundaries, get_bhotekoshi_corridor }
sv import from ...services.trace { LocationView, PersonView }

# The incident's district in geometry.topo.json (सिन्धुपाल्चोक / Sindhupalchok).
glob INCIDENT_DISTRICT_ID: int = 30;

# Read a CSS variable (e.g. "--primary") so map colours follow the theme tokens.
# The theme uses oklch(...) colours, which MapLibre cannot parse, so we let a
# tiny canvas convert the colour to "rgba(...)" first.
def css_var(name: str) -> str {
    styles: any = getComputedStyle(document.documentElement);
    raw: str = styles.getPropertyValue(name).trim();
    canvas: any = document.createElement("canvas");
    canvas.width = 1;
    canvas.height = 1;
    ctx: any = canvas.getContext("2d");
    ctx.fillStyle = raw;
    ctx.fillRect(0, 0, 1, 1);
    px: any = ctx.getImageData(0, 0, 1, 1).data;
    return "rgba(" + str(px[0]) + "," + str(px[1]) + "," + str(px[2]) + "," + str(px[3] / 255) + ")";
}

# A blank style: no tiles, no internet needed. Our GeoJSON layers go on top.
def blank_style() -> dict {
    return {
        "version": 8,
        "sources": {},
        "layers": [{"id": "bg", "type": "background", "paint": {"background-color": css_var("--map-surface")}}]
    };
}

def add_boundary_layers(map_obj: any, topo: any) -> None {
    districts = feature(topo, topo.objects.districts);
    provinces = feature(topo, topo.objects.provinces);
    map_obj.addSource("districts", {"type": "geojson", "data": districts});
    map_obj.addSource("provinces", {"type": "geojson", "data": provinces});

    map_obj.addLayer({
        "id": "district-fill", "type": "fill", "source": "districts",
        "paint": {
            "fill-color": ["case", ["==", ["get", "district_id"], INCIDENT_DISTRICT_ID], css_var("--map-land"), css_var("--map-land")],
            "fill-opacity": ["case", ["==", ["get", "district_id"], INCIDENT_DISTRICT_ID], 0.6, 1]
        }
    });
    map_obj.addLayer({
        "id": "district-line", "type": "line", "source": "districts",
        "paint": {"line-color": ["case", ["==", ["get", "district_id"], INCIDENT_DISTRICT_ID], css_var("--primary"), css_var("--map-grid")], "line-width": 0.8, "line-opacity": 0.6}
    });
    map_obj.addLayer({
        "id": "province-line", "type": "line", "source": "provinces",
        "paint": {"line-color": css_var("--muted-foreground"), "line-width": 1.2, "line-opacity": 0.6}
    });
    # Requests may finish in either order; late boundaries stay under the river.
    if map_obj.getLayer("corridor-band") {
        for layer in ["district-fill", "district-line", "province-line"] {
            map_obj.moveLayer(layer, "corridor-band");
        }
    }
}


def add_corridor_layers(map_obj: any, corridor: any) -> list {
    map_obj.addSource("bhotekoshi-corridor", {"type": "geojson", "data": corridor,
        "attribution": "© <a href='https://www.openstreetmap.org/copyright' target='_blank' rel='noopener noreferrer'>OpenStreetMap contributors</a> (ODbL)"});
    map_obj.addLayer({"id": "corridor-band", "type": "line", "source": "bhotekoshi-corridor",
        "filter": ["==", ["geometry-type"], "LineString"],
        "layout": {"line-cap": "round", "line-join": "round"},
        "paint": {"line-color": css_var("--primary"), "line-opacity": 0.13,
            "line-width": ["interpolate", ["linear"], ["zoom"], 8, 10, 12, 28, 16, 52]}});
    map_obj.addLayer({"id": "corridor-river", "type": "line", "source": "bhotekoshi-corridor",
        "filter": ["==", ["geometry-type"], "LineString"],
        "layout": {"line-cap": "round", "line-join": "round"},
        "paint": {"line-color": css_var("--primary"), "line-opacity": 0.9,
            "line-width": ["interpolate", ["linear"], ["zoom"], 8, 1.5, 12, 3.5, 16, 6]}});
    labels: list = [];
    # HTML labels keep offline text rendering independent of a remote glyph server.
    for item in corridor.features {
        if item.geometry.type == "Point" {
            label: any = document.createElement("span");
            label.className = "pointer-events-none rounded bg-card/90 px-1.5 py-0.5 text-xs font-medium text-primary shadow-sm";
            label.textContent = item.properties.label;
            label.setAttribute("data-corridor-settlement", item.properties.label);
            marker: any = new(Marker, {"element": label, "anchor": "bottom-left", "offset": [8, -8]});
            marker.setLngLat(item.geometry.coordinates).addTo(map_obj);
            labels.append(marker);
        }
    }
    return labels;
}

# A small HTML pin. Classes use theme tokens.
def make_pin(label: str, location_id: str, status: str, on_select: Callable[[str], None]) -> any {
    el: any = document.createElement("button");
    el.type = "button";
    el.setAttribute("aria-label", "Inspect " + label + " · " + pin_label(status));
    el.addEventListener("click", lambda { on_select(location_id); });
    el.className = "flex cursor-pointer flex-col items-center gap-1 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring";
    dot: any = document.createElement("span");
    dot.className = "block size-3.5 rounded-full border-2 border-background shadow " + pin_dot(status);
    tag: any = document.createElement("span");
    tag.className = "whitespace-nowrap rounded border border-border bg-card/95 px-1.5 py-0.5 text-[10px] font-medium text-foreground shadow-sm";
    tag.textContent = label;
    el.appendChild(dot);
    el.appendChild(tag);
    return el;
}

def:pub IncidentMap(locations: list[LocationView], people: list[PersonView], active: bool = True, className: str = "", focusLocationId: str = "", focusRequest: int = 0, onSelect: Callable[[str], None] | None = None) -> JsxElement {
    has containerRef: Ref[HTMLDivElement] = Ref(),
        mapRef: Ref[any] = Ref(None),
        markersRef: Ref[list] = Ref([]),
        settlementMarkersRef: Ref[list] = Ref([]),
        corridorStatus: str = "loading",
        corridorTimerRef: Ref[any] = Ref(None),
        onSelectRef: Ref[any] = Ref(None),
        status: str = "loading",    # loading | ready | error
        errorText: str = "",
        boundaryStatus: str = "loading",
        boundaryTimerRef: Ref[any] = Ref(None),
        resizeRef: Ref[any] = Ref(None),
        lastFocusRequest: Ref[int] = Ref(0);

    def select_location(location_id: str) -> None {
        if onSelectRef.current { onSelectRef.current(location_id); }
    }

    can with [onSelect] entry { onSelectRef.current = onSelect; }

    # Start the map immediately. Boundary loading never gates evidence or pins.
    can with entry {
        if mapRef.current or not containerRef.current { return; }
        try {
            map_obj: any = new(MapLibreMap, {
                "container": containerRef.current,
                "style": blank_style(),
                "bounds": [[85.82, 27.74], [86.00, 28.06]],
                "fitBoundsOptions": {"padding": 42},
                "attributionControl": False
            });
            mapRef.current = map_obj;
            map_obj.addControl(new(NavigationControl, {"showCompass": False}), "top-left");
            map_obj.addControl(new(AttributionControl, {"compact": True,
                "customAttribution": "© <a href='https://www.openstreetmap.org/copyright' target='_blank' rel='noopener noreferrer'>OpenStreetMap contributors</a> (ODbL)"}), "bottom-right");
            map_obj.on("load", lambda {
                if mapRef.current != map_obj { return; }
                # Initial corridor fit is independent of sparse demo pins.
                # Later refreshes and tab switches preserve the viewport.
                status = "ready";
                load_boundaries(map_obj);
                load_corridor(map_obj);
            });
            # Browser constructor lacks a Jac stub; see jac-cl-js-interop.
            observer: any = new(ResizeObserver, lambda { # jac:ignore[E1053]
                if mapRef.current { mapRef.current.resize(); }
            });
            resizeRef.current = observer;
            observer.observe(containerRef.current);
        } except Exception as e {
            status = "error";
            errorText = str(e);
        }
    }

    async def load_boundaries(map_obj: any) -> None {
        # Show a useful fallback after five seconds; a late success may recover.
        boundaryTimerRef.current = setTimeout(lambda {
            if mapRef.current == map_obj { boundaryStatus = "unavailable"; }
        }, 5000);
        try {
            topo: any = await get_boundaries();
            if mapRef.current != map_obj { return; }
            if topo["error"] { boundaryStatus = "unavailable"; }
            else {
                add_boundary_layers(map_obj, topo);
                boundaryStatus = "ready";
            }
        } except Exception {
            if mapRef.current == map_obj { boundaryStatus = "unavailable"; }
        } finally {
            if boundaryTimerRef.current { clearTimeout(boundaryTimerRef.current); }
        }
    }

    async def load_corridor(map_obj: any) -> None {
        corridorTimerRef.current = setTimeout(lambda {
            if mapRef.current == map_obj { corridorStatus = "unavailable"; }
        }, 5000);
        try {
            corridor: any = await get_bhotekoshi_corridor();
            if mapRef.current != map_obj { return; }
            if corridor["error"] { corridorStatus = "unavailable"; }
            else {
                settlementMarkersRef.current = add_corridor_layers(map_obj, corridor);
                corridorStatus = "ready";
            }
        } except Exception {
            if mapRef.current == map_obj { corridorStatus = "unavailable"; }
        } finally {
            if corridorTimerRef.current { clearTimeout(corridorTimerRef.current); }
        }
    }

    # Keep pins in sync with the Location nodes (runs after every render).
    can with [locations, people, status] entry {
        map_obj = mapRef.current;
        if not map_obj or status != "ready" { return; }
        for m in markersRef.current { m.remove(); }
        fresh: list = [];
        for loc in locations {
            marker: any = new(Marker, {"element": make_pin(loc.name, loc.id, pin_status(linked_people(loc, people)), select_location), "anchor": "top"});
            marker.setLngLat([loc.longitude, loc.latitude]).addTo(map_obj);
            fresh.append(marker);
        }
        markersRef.current = fresh;
    }

    # Tab panels stay mounted. Recalculate the canvas after the map becomes visible.
    can with [active, status] entry {
        if active and status == "ready" and mapRef.current {
            mapRef.current.resize();
        }
    }

    # Only explicit report navigation recenters; refresh and ordinary tab switches
    # preserve the user's viewport. Wait for map readiness and visible dimensions.
    can with [focusLocationId, focusRequest, active, status] entry {
        if not active or status != "ready" or not mapRef.current { return; }
        if focusRequest <= lastFocusRequest.current { return; }
        places = [p for p in locations if p.id == focusLocationId];
        if not places { return; }
        mapRef.current.resize();
        mapRef.current.jumpTo({"center": [places[0].longitude, places[0].latitude],
            "zoom": max(mapRef.current.getZoom(), 13)});
        lastFocusRequest.current = focusRequest;
    }

    # Remove the map when the component unmounts.
    can with exit {
        if boundaryTimerRef.current { clearTimeout(boundaryTimerRef.current); }
        if corridorTimerRef.current { clearTimeout(corridorTimerRef.current); }
        for marker in settlementMarkersRef.current { marker.remove(); }
        if resizeRef.current { resizeRef.current.disconnect(); }
        if mapRef.current { mapRef.current.remove(); mapRef.current = None; }
    }

    return <div className={cn("relative h-full w-full overflow-hidden rounded-md border border-border bg-map-surface", className)}>
        {#* Explicit size: MapLibre's CSS forces position:relative on this div, so f"absolute inset-0" would collapse it to 0px tall. *#}
        <div ref={containerRef} className="h-full min-h-80 w-full" />
        {status == "loading" and <div className="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground">{"Loading river corridor map..."}</div>}
        {status == "ready" and boundaryStatus != "ready" and <p role="status" className="pointer-events-none absolute bottom-2 left-2 right-2 rounded border border-border bg-card/95 p-2 text-center text-xs text-muted-foreground">
            {"Boundaries unavailable. Pins, place list, and linked evidence remain available." if boundaryStatus == "unavailable" else "Loading district boundaries; pins and evidence are ready."}
        </p>}
        {status == "ready" and corridorStatus != "ready" and <p role="status" className="pointer-events-none absolute top-2 left-12 right-2 rounded border border-border bg-card/95 p-2 text-center text-xs text-muted-foreground">
            {"River corridor unavailable; reported places and evidence remain usable." if corridorStatus == "unavailable" else "Loading current river linework..."}
        </p>}
        {status == "error" and <div className="absolute inset-0 flex items-center justify-center pl-6 pr-6 text-center text-sm text-destructive">{"Map unavailable: " + errorText}</div>}
    </div>;
}
