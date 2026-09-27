"""IncidentMap - interactive map of Nepal drawn with MapLibre GL.

MapLibre is the open-source fork of Mapbox GL JS: same kind of API, but no
access token, so the demo keeps working offline.

What it draws:
  - district + province borders from geometry.topo.json (via get_boundaries)
  - the incident's district highlighted (Sindhupalchok, district_id 30)
  - one pin per Location node from the Trace graph

JS interop notes (see f"jac guide jac-cl-js-interop"):
  - f"new(maplibregl.Map, {...})" is how Jac calls a JS constructor.
  - The map object lives in a Ref so re-renders don't recreate it.
  - Colours are read from CSS variables, so the map follows the theme.
"""

import from "maplibre-gl" { Map as MapLibreMap, Marker, NavigationControl }
import "maplibre-gl/dist/maplibre-gl.css";
import from "topojson-client" { feature }
import from ...lib.utils { cn }
import from .Status { linked_people, pin_status, pin_label, pin_dot }
sv import from ...services.geo { get_boundaries }
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
            "fill-color": ["case", ["==", ["get", "district_id"], INCIDENT_DISTRICT_ID], css_var("--primary"), css_var("--map-land")],
            "fill-opacity": ["case", ["==", ["get", "district_id"], INCIDENT_DISTRICT_ID], 0.45, 1]
        }
    });
    map_obj.addLayer({
        "id": "district-line", "type": "line", "source": "districts",
        "paint": {"line-color": css_var("--map-grid"), "line-width": 0.6}
    });
    map_obj.addLayer({
        "id": "province-line", "type": "line", "source": "provinces",
        "paint": {"line-color": css_var("--muted-foreground"), "line-width": 1.2, "line-opacity": 0.6}
    });
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
                "bounds": [[80.05, 26.34], [88.21, 30.48]],
                "fitBoundsOptions": {"padding": 16},
                "attributionControl": False
            });
            mapRef.current = map_obj;
            map_obj.addControl(new(NavigationControl, {"showCompass": False}), "top-left");
            map_obj.on("load", lambda {
                if mapRef.current != map_obj { return; }
                # Fit once; later refreshes and tab switches retain the viewport.
                if len(locations) > 0 {
                    west = locations[0].longitude;
                    east = west;
                    south = locations[0].latitude;
                    north = south;
                    for loc in locations {
                        west = min(west, loc.longitude);
                        east = max(east, loc.longitude);
                        south = min(south, loc.latitude);
                        north = max(north, loc.latitude);
                    }
                    map_obj.fitBounds([[west, south], [east, north]],
                        {"padding": 70, "maxZoom": 13, "duration": 0});
                }
                status = "ready";
                load_boundaries(map_obj);
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
        if resizeRef.current { resizeRef.current.disconnect(); }
        if mapRef.current { mapRef.current.remove(); mapRef.current = None; }
    }

    return <div className={cn("relative h-full w-full overflow-hidden rounded-md border border-border bg-map-surface", className)}>
        {#* Explicit size: MapLibre's CSS forces position:relative on this div, so f"absolute inset-0" would collapse it to 0px tall. *#}
        <div ref={containerRef} className="h-full min-h-80 w-full" />
        {status == "loading" and <div className="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground">{"Loading map of Nepal..."}</div>}
        {status == "ready" and boundaryStatus != "ready" and <p role="status" className="pointer-events-none absolute bottom-2 left-2 right-2 rounded border border-border bg-card/95 p-2 text-center text-xs text-muted-foreground">
            {"Boundaries unavailable. Pins, place list, and linked evidence remain available." if boundaryStatus == "unavailable" else "Loading district boundaries; pins and evidence are ready."}
        </p>}
        {status == "error" and <div className="absolute inset-0 flex items-center justify-center pl-6 pr-6 text-center text-sm text-destructive">{"Map unavailable: " + errorText}</div>}
    </div>;
}
