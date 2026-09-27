"""Guided walk through Maya's story for live demos. Coordinate changes with Anshu.

Each step only switches the view and explains it. The big button runs the real
action (the same handlers as Demo controls), so nothing is faked or automatic.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Location01Icon, UserSearch01Icon, Hospital01Icon, Search01Icon,
    CheckmarkCircle02Icon, ArrowRight01Icon, RotateLeft01Icon, Share08Icon
}
import from ..ui.button { Button }
import from .InfoTip { InfoTip }
import from ...lib.utils { cn }

glob STORY_STEPS: list[dict] = [
    {"short": "Reported missing",
     "title": "Maya is reported missing",
     "caption": "After the flood, the police and a volunteer desk each send a report about Maya. Trace keeps both, with who said it and when.",
     "action": "See every report about Maya",
     "note": "The red pin marks the bridge named in the police report. It is not live tracking."},
    {"short": "Same person?",
     "title": "Is \"Maya G.\" the same person?",
     "caption": "A volunteer post mentions \"Maya G., 24\". Trace explains why it could be Maya, but only a person can confirm. Both records are kept either way.",
     "action": "Review the possible match",
     "note": "Names alone are never enough. ResolveWalker compares first name, surname or initial, age and incident, and lists what it could not check. The decision records who made it and when."},
    {"short": "Hospital says safe",
     "title": "The hospital says Maya is safe",
     "caption": "Central Hospital reports Maya safe. The police report still says missing, so Trace shows both side by side and alerts her family.",
     "action": "Publish the demo hospital report",
     "note": "This button publishes the prepared demo report; the Sources tab can publish one by hand. Under the hood, IngestWalker stores the report, then WatchWalker walks from Maya to everyone following her and creates one alert each."},
    {"short": "Where did it come from?",
     "title": "Where did this report come from?",
     "caption": "The volunteer post says \"According to Nepal Police\". Trace asks NVIDIA Nemotron who is being quoted, then compares the post with that source.",
     "action": "Check the report's source",
     "note": "The model only labels the attribution. Jac decides what to do next, and a person makes the final call. Saved checks are marked REPLAYED."}
];
glob STORY_ICONS: list = [Location01Icon, UserSearch01Icon, Hospital01Icon, Search01Icon];
# One colour per step so the audience can follow along: missing (red),
# identity (violet), safe (green), provenance (brand orange).
glob STORY_DOT: list[str] = ["bg-status-missing text-background", "bg-story-match text-background", "bg-status-safe text-background", "bg-brand text-background"];
glob STORY_SOFT: list[str] = ["bg-status-missing-soft border-status-missing/40", "bg-story-match-soft border-story-match/40", "bg-status-safe-soft border-status-safe/40", "bg-brand-soft border-brand/40"];
glob STORY_TEXT: list[str] = ["text-status-missing", "text-story-match", "text-status-safe", "text-brand"];

# Which dashboard tab a step shows. Explicit cl keeps this a browser helper
# (not a server call) when the shell imports it, as in Display.jac.
cl def:pub story_tab(step: int) -> str {
    if step == 2 or step == 4 { return "People"; }
    return "Map";
}

# Vertical story rail: the active step opens into a card with one big button;
# the others stay one line so the whole story is visible at a glance.
def:pub StoryRail(step: int, hospitalAdded: bool, busy: str,
    onStep: Callable[[int], None], onAction: Callable[[int], None],
    onShowGraph: Callable[[], None], onReset: Callable[[], None]) -> JsxElement {
    action_done: bool = step == 3 and hospitalAdded;

    return <section aria-label="Maya's story, step by step" className="flex flex-col gap-4 rounded-3xl border border-border bg-card p-4 shadow-sm md:p-5">
        <div className="flex items-start justify-between gap-3">
            <div className="flex flex-col">
                <span className="text-xs font-semibold uppercase tracking-wide text-brand">{"Follow the story"}</span>
                <h2 className="font-display text-2xl leading-tight">{"What happened to Maya?"}</h2>
            </div>
            <Button variant="ghost" size="sm" disabled={busy != ""} onClick={lambda { onReset(); }}>
                <HugeiconsIcon icon={RotateLeft01Icon} strokeWidth={2} />{"Start over"}
            </Button>
        </div>
        <ol className="relative flex flex-col gap-2">
            <span className="absolute top-5 bottom-5 left-[1.3rem] w-0.5 bg-border" aria-hidden="true" />
            {for i in range(len(STORY_STEPS)) {
                <li key={STORY_STEPS[i]["short"]} className="relative">
                    {step != i + 1 and <button type="button" onClick={lambda { onStep(i + 1); }}
                        className="flex w-full items-center gap-3 rounded-2xl px-1.5 py-1.5 text-left transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
                        <span className={cn("relative z-10 inline-flex size-9 shrink-0 items-center justify-center rounded-full text-sm font-bold shadow-sm ring-4 ring-card",
                            STORY_DOT[i] if i + 1 < step else "bg-muted text-muted-foreground")}>
                            {i + 1 < step and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2.5} className="size-5" />}
                            {i + 1 >= step and str(i + 1)}
                        </span>
                        <span className={cn("text-base font-medium", "text-foreground" if i + 1 < step else "text-muted-foreground")}>{STORY_STEPS[i]["short"]}</span>
                    </button>}
                    {step == i + 1 and <div aria-current="step"
                        className={cn("flex flex-col gap-3 rounded-2xl border-2 p-3 animate-in fade-in slide-in-from-left-2 duration-300 motion-reduce:animate-none", STORY_SOFT[i])}>
                        <div className="flex items-center gap-3">
                            <span className={cn("relative z-10 inline-flex size-10 shrink-0 items-center justify-center rounded-full shadow-md ring-4 ring-card", STORY_DOT[i])}>
                                <HugeiconsIcon icon={STORY_ICONS[i]} strokeWidth={2} className="size-5" />
                            </span>
                            <div className="flex min-w-0 flex-col">
                                <span className={cn("text-xs font-bold uppercase tracking-wide", STORY_TEXT[i])}>{"Step " + str(i + 1) + " of " + str(len(STORY_STEPS))}</span>
                                <div className="flex items-center gap-1">
                                    <h3 className="font-display text-xl leading-tight md:text-2xl">{STORY_STEPS[i]["title"]}</h3>
                                    <InfoTip label="More about this step" lines={[STORY_STEPS[i]["note"]]} />
                                </div>
                            </div>
                        </div>
                        <p className="text-base leading-relaxed text-foreground/85 md:text-lg">{STORY_STEPS[i]["caption"]}</p>
                        <Button size="lg" className="h-12 w-full rounded-xl text-base shadow-md" disabled={busy != "" or action_done}
                            onClick={lambda { onAction(step); }}>
                            {action_done and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} />}
                            {"Hospital report published" if action_done else ("Publishing..." if step == 3 and busy == "hospital" else STORY_STEPS[i]["action"])}
                        </Button>
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            {step == 4 and <Button variant="outline" size="lg" className="h-10 rounded-xl" onClick={lambda { onShowGraph(); }}>
                                <HugeiconsIcon icon={Share08Icon} strokeWidth={2} />{"Show the graph"}
                            </Button>}
                            {step < len(STORY_STEPS) and <Button variant="ghost" size="lg" className="ml-auto h-10 rounded-xl" onClick={lambda { onStep(step + 1); }}>
                                {"Next step"}<HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} />
                            </Button>}
                        </div>
                    </div>}
                </li>
            }}
        </ol>
    </section>;
}
