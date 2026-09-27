"""Large banner for a freshly created alert. Coordinate changes with Anshu.

Everything shown comes from the snapshot: the alert WatchWalker stored, the
claim it cites, and the other status reports kept for the same person.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Notification01Icon, Cancel01Icon, Location01Icon }
import from ..ui.button { Button }
import from .Display { status_sentence, status_badge }
import from ...lib.utils { cn }
sv import from ...services.trace { AlertView, PersonView, ClaimView }

glob BANNER_STATUS_CLAIMS: list[str] = ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED"];

def:pub AlertBanner(alert: AlertView, people: list[PersonView], onDismiss: Callable[[], None], onShowOnMap: Callable[[str], None]) -> JsxElement {
    # onShowOnMap takes a person id; the new claim itself may have no place.
    # any: both stay None when the cited claim is no longer in the snapshot.
    person: any = None;
    cited: any = None;
    for p in people {
        for c in p.claims {
            if c.id == alert.claim_id { person = p; cited = c; }
        }
    }
    kept: list[ClaimView] = [c for c in person.claims if c.claim_type in BANNER_STATUS_CLAIMS and c.id != alert.claim_id] if person else [];
    headline: str = (person.name + " " + status_sentence(cited.claim_type).lower() + " by " + cited.source_name) if person and cited else "New report received";

    return <section role="status" aria-live="polite" aria-label="New alert"
        className={cn("mx-4 mt-4 flex flex-col gap-3 rounded-xl border-2 p-4 shadow-lg animate-in fade-in slide-in-from-top-4 duration-500 motion-reduce:animate-none md:mx-6 md:flex-row md:items-center md:justify-between md:p-5",
            "border-primary bg-accent")}>
        <div className="flex min-w-0 items-start gap-4">
            <span className="relative mt-1 inline-flex size-11 shrink-0 items-center justify-center" aria-hidden="true">
                <span className={cn("absolute inset-0 animate-ping rounded-full opacity-40 motion-reduce:animate-none", "bg-primary")} />
                <span className={cn("relative inline-flex size-11 items-center justify-center rounded-full", "bg-primary text-primary-foreground")}>
                    <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="size-5" />
                </span>
            </span>
            <div className="flex min-w-0 flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{"Alert sent to " + alert.subscriber_name}</span>
                <h2 className="font-display text-2xl leading-tight md:text-3xl">{headline}</h2>
                {len(kept) > 0 and <div className="flex flex-wrap items-center gap-2 text-sm md:text-base">
                    <span className="text-muted-foreground">{"Still on record, not overwritten:"}</span>
                    {for c in kept {
                        <span key={c.id} className={cn("rounded-full border px-2.5 py-0.5 text-sm font-medium", status_badge(c.claim_type))}>
                            {c.source_name + " · " + status_sentence(c.claim_type)}
                        </span>
                    }}
                </div>}
                <p className="text-sm text-muted-foreground">{alert.message}</p>
            </div>
        </div>
        <div className="flex shrink-0 items-center gap-2">
            {person and <Button variant="outline" size="lg" className="h-10" onClick={lambda { onShowOnMap(person.id); }}>
                <HugeiconsIcon icon={Location01Icon} strokeWidth={2} />{"Show on map"}
            </Button>}
            <Button variant="ghost" size="icon-lg" aria-label="Dismiss alert" onClick={lambda { onDismiss(); }}>
                <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
            </Button>
        </div>
    </section>;
}
