"""Small (i) disclosure: keeps caveats one click away instead of always on screen.

Uses a native <details> element, so it works with keyboard and screen readers
without extra state. Set floating=False inside clipped containers (the map).
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { InformationCircleIcon }
import from ...lib.utils { cn }

def:pub InfoTip(label: str, lines: list[str], floating: bool = True, contentLabel: str = "") -> JsxElement {
    return <details className={cn("group text-left", "relative inline-block align-middle" if floating else "block")}>
        <summary aria-label={label} title={label}
            className="inline-flex size-7 cursor-pointer list-none items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring group-open:text-primary [&::-webkit-details-marker]:hidden">
            <HugeiconsIcon icon={InformationCircleIcon} strokeWidth={2} className="size-4" />
        </summary>
        <div aria-label={contentLabel or label}
            className={cn("flex flex-col gap-2 text-xs leading-relaxed",
                "absolute left-0 top-full z-30 mt-1 w-80 max-w-[calc(100vw-2rem)] rounded-md border border-border bg-popover p-3 text-popover-foreground shadow-lg" if floating else "mt-1 text-muted-foreground")}>
            {for line in lines { <p key={line} className="break-words">{line}</p> }}
        </div>
    </details>;
}
