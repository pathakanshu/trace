"""Guided walk through Maya's story for live demos. Coordinate changes with Anshu.

Each step only switches the view and explains it. The big button runs the real
action (the same handlers as Demo controls), so nothing is faked or automatic.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Location01Icon, UserSearch01Icon, Hospital01Icon, Search01Icon,
    CheckmarkCircle02Icon, ArrowRight01Icon, ArrowDown01Icon, ArrowUp01Icon,
    RotateLeft01Icon, Share08Icon
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

# Which dashboard tab a step shows. Explicit cl keeps this a browser helper
# (not a server call) when the shell imports it, as in Display.jac.
cl def:pub story_tab(step: int) -> str {
    if step == 2 or step == 4 { return "People"; }
    return "Map";
}

def:pub StoryBar(step: int, hospitalAdded: bool, busy: str,
    onStep: Callable[[int], None], onAction: Callable[[int], None],
    onShowGraph: Callable[[], None], onReset: Callable[[], None]) -> JsxElement {
    has collapsed: bool = False;
    current: dict = STORY_STEPS[step - 1];
    action_done: bool = step == 3 and hospitalAdded;
    action_label: str = current["action"];
    if action_done { action_label = "Hospital report published"; }
    if step == 3 and busy == "hospital" { action_label = "Publishing..."; }
    if step == 2 and busy == "resolve" { action_label = "Looking for matches..."; }

    return <section aria-label="Maya's story, step by step" className="border-b border-border bg-card/60">
        <div className="flex flex-col gap-3 px-4 py-3 md:px-6">
            <div className="flex flex-wrap items-center gap-2">
                <span className="mr-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{"Maya's story"}</span>
                <ol className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">
                    {for i in range(len(STORY_STEPS)) {
                        <li key={STORY_STEPS[i]["short"]} className="flex items-center gap-1.5">
                            <button type="button" aria-current={"step" if step == i + 1 else None}
                                onClick={lambda { onStep(i + 1); }}
                                className={cn("inline-flex min-h-10 items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                                    "border-primary bg-primary text-primary-foreground shadow-sm" if step == i + 1
                                    else ("border-primary/40 bg-primary/10 text-foreground hover:bg-primary/20" if i + 1 < step
                                    else "border-border bg-background text-muted-foreground hover:bg-accent hover:text-foreground"))}>
                                <span className={cn("inline-flex size-6 items-center justify-center rounded-full text-xs font-bold",
                                    "bg-primary-foreground text-primary" if step == i + 1 else "bg-muted text-foreground")}>
                                    {i + 1 < step and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />}
                                    {i + 1 >= step and str(i + 1)}
                                </span>
                                {STORY_STEPS[i]["short"]}
                            </button>
                            {i < len(STORY_STEPS) - 1 and <span className="hidden h-px w-4 bg-border md:block" aria-hidden="true" />}
                        </li>
                    }}
                </ol>
                <Button variant="ghost" size="sm" disabled={busy != ""} onClick={lambda { onReset(); }}>
                    <HugeiconsIcon icon={RotateLeft01Icon} strokeWidth={2} />{"Start over"}
                </Button>
                <Button variant="ghost" size="icon-sm" aria-label={"Show story guide" if collapsed else "Hide story guide"}
                    aria-expanded={not collapsed} onClick={lambda { collapsed = not collapsed; }}>
                    <HugeiconsIcon icon={ArrowDown01Icon if collapsed else ArrowUp01Icon} strokeWidth={2} />
                </Button>
            </div>
            {not collapsed and <div key={step}
                className="flex flex-col gap-4 rounded-xl border border-border bg-background p-4 shadow-sm animate-in fade-in slide-in-from-bottom-2 duration-300 motion-reduce:animate-none lg:flex-row lg:items-center lg:justify-between">
                <div className="flex min-w-0 items-start gap-4">
                    <span className="hidden size-12 shrink-0 items-center justify-center rounded-full bg-primary/15 text-primary sm:inline-flex" aria-hidden="true">
                        <HugeiconsIcon icon={STORY_ICONS[step - 1]} strokeWidth={2} className="size-6" />
                    </span>
                    <div className="flex min-w-0 flex-col gap-1">
                        <span className="text-xs font-semibold uppercase tracking-wide text-primary">{"Step " + str(step) + " of " + str(len(STORY_STEPS))}</span>
                        <div className="flex items-center gap-1">
                            <h2 className="font-display text-2xl leading-tight tracking-tight md:text-3xl">{current["title"]}</h2>
                            <InfoTip label="More about this step" lines={[current["note"]]} />
                        </div>
                        <p className="max-w-3xl text-base text-muted-foreground md:text-lg">{current["caption"]}</p>
                    </div>
                </div>
                <div className="flex shrink-0 flex-wrap items-center gap-2">
                    <Button size="lg" className="h-11 px-5 text-base" disabled={busy != "" or action_done}
                        onClick={lambda { onAction(step); }}>
                        {action_done and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} />}
                        {action_label}
                    </Button>
                    {step == 4 and <Button variant="outline" size="lg" className="h-11 px-4 text-base" onClick={lambda { onShowGraph(); }}>
                        <HugeiconsIcon icon={Share08Icon} strokeWidth={2} />{"Show the graph"}
                    </Button>}
                    {step < len(STORY_STEPS) and <Button variant="ghost" size="lg" className="h-11 px-4 text-base" onClick={lambda { onStep(step + 1); }}>
                        {"Next"}<HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} />
                    </Button>}
                </div>
            </div>}
        </div>
    </section>;
}
