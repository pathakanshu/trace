"""Legend drawn over the map, so the key sits where the audience is looking.

The body stays in the DOM when collapsed (hidden), so layout checks that look up
the corridor caveat by aria-label still find it.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowDown01Icon, ArrowUp01Icon }
import from .Status { pin_label, pin_dot }

def:pub MapLegend(showPins: bool, showHeat: bool) -> JsxElement {
    has open: bool = True;

    # Phones start collapsed so the legend does not cover the pins.
    can with entry {
        if window.innerWidth < 640 { open = False; }
    }

    caveats: list[str] = [];
    if showPins {
        caveats.append("Pin colour follows the latest reports about the people linked to that place. Needs review covers disagreeing reports, injury or death.");
        caveats.append("Pins mark places named in reports. They are not live tracking of anyone.");
    }
    if showHeat {
        caveats.append("Heat counts reports, not unique people, image locations or flood severity. The glow is a display effect.");
    }

    return <div role="group" aria-label="Map status legend"
        className="absolute bottom-3 left-3 z-10 max-w-[calc(100%-1.5rem)] rounded-lg border border-border bg-card/90 text-card-foreground shadow-lg backdrop-blur-sm sm:max-w-xs">
        <button type="button" aria-expanded={open} onClick={lambda { open = not open; }}
            className="flex w-full items-center justify-between gap-6 rounded-lg px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
            {"Legend"}
            <HugeiconsIcon icon={ArrowDown01Icon if open else ArrowUp01Icon} strokeWidth={2} className="size-4" />
        </button>
        <div hidden={not open} className="flex flex-col gap-2.5 border-t border-border px-3 pt-2.5 pb-3 text-sm">
            {showPins and <div className="grid grid-cols-2 gap-x-4 gap-y-1.5">
                {for status in ["MISSING", "REVIEW", "FOUND_SAFE", "UNKNOWN"] {
                    <span key={status} className="inline-flex items-center gap-2">
                        <span className={"size-3 shrink-0 rounded-full border-2 border-background shadow " + pin_dot(status)} aria-hidden="true" />{pin_label(status)}
                    </span>
                }}
            </div>}
            {showHeat and <div className="flex items-center gap-2" aria-label="Report density legend">
                <span className="text-xs text-muted-foreground">{"Fewer reports"}</span>
                <span className="size-3 rounded-full bg-primary" aria-hidden="true" />
                <span className="size-3 rounded-full bg-status-warning" aria-hidden="true" />
                <span className="size-3 rounded-full bg-status-missing" aria-hidden="true" />
                <span className="text-xs text-muted-foreground">{"More"}</span>
            </div>}
            <span className="inline-flex items-center gap-2"><span className="h-1 w-6 shrink-0 rounded-full bg-status-warning" aria-hidden="true" />{"Flooded river: Bhote Koshi"}</span>
            <span className="inline-flex items-center gap-2"><span className="h-0.5 w-6 shrink-0 bg-map-water" aria-hidden="true" />{"Other rivers"}</span>
            <span className="inline-flex items-center gap-2"><span className="h-0.5 w-6 shrink-0 bg-primary/60" aria-hidden="true" />{"Sindhupalchok district"}</span>
            <div className="flex flex-col gap-1.5 border-t border-border pt-2 text-xs text-muted-foreground">
                <p className="break-words" aria-label="River corridor context">{"River line from today's OpenStreetMap, not the measured 2016 flood."}</p>
                {len(caveats) > 0 and <details>
                    <summary className="cursor-pointer text-primary">{"How to read this map"}</summary>
                    <ul className="mt-1.5 flex list-disc flex-col gap-1.5 pl-4">
                        {for line in caveats { <li key={line} className="break-words">{line}</li> }}
                    </ul>
                </details>}
            </div>
        </div>
    </div>;
}
