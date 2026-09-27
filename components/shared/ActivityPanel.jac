"""Shared in-app alerts and activity. Refreshed from the same dashboard snapshot."""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Notification01Icon }
import from .Display { SectionHeading, EmptyPanel, friendly_time }
sv import from ...services.trace { AlertView, ActivityView }

# ---------------- Notifications + recent updates ----------------
# compact: the shell's left column, where the activity log folds away.
def:pub AlertsPanel(alerts: list[AlertView], activity: list[ActivityView], compact: bool = False) -> JsxElement {
    return <section className={"flex flex-col gap-3" + (" rounded-3xl border border-border bg-card p-4 shadow-sm md:p-5" if compact else "")}>
        <SectionHeading title={"Family notifications" if compact else "Notifications"} subtitle="Sent to people following someone when new information arrives." />
        {len(alerts) == 0 and <EmptyPanel icon={Notification01Icon} title="No notifications yet" text="When a new report comes in about someone, their followers are notified here." />}
        {for a in alerts {
            <div key={a.created_at + a.message} className="flex items-start gap-3 rounded-xl border border-primary/30 bg-accent pt-3 pb-3 pl-3 pr-3 animate-in fade-in slide-in-from-bottom-2 duration-500 motion-reduce:animate-none">
                <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">{"Sent to " + a.subscriber_name}</span>
                    <span className="text-sm text-muted-foreground">{a.message}</span>
                    <span className="text-[11px] text-muted-foreground">{friendly_time(a.created_at)}</span>
                </div>
            </div>
        }}
        {compact and <details className="group text-sm">
            <summary className="cursor-pointer list-none text-primary [&::-webkit-details-marker]:hidden">
                {"Show activity log (" + str(len(activity)) + ")"}
            </summary>
            <div className="mt-2 flex max-h-72 flex-col divide-y divide-border overflow-y-auto border-t border-border">
                {for e in activity {
                    <div key={e.created_at + e.message} className="flex flex-col gap-0.5 pt-2 pb-2">
                        <span className="text-foreground">{e.message}</span>
                        <span className="text-[11px] text-muted-foreground">{friendly_time(e.created_at)}</span>
                    </div>
                }}
            </div>
        </details>}
        {not compact and <div className="flex flex-col gap-2 pt-2">
            <div className="flex items-baseline justify-between">
                <h3 className="font-display text-lg">{"Recent updates"}</h3>
                <span className="text-xs text-muted-foreground">{"newest first"}</span>
            </div>
            {len(activity) == 0 and <span className="text-sm text-muted-foreground">{"Nothing has happened yet."}</span>}
            <div className="flex max-h-72 flex-col divide-y divide-border overflow-y-auto border-t border-border">
                {for e in activity {
                    <div key={e.created_at + e.message} className="flex flex-col gap-0.5 pt-2 pb-2 text-sm">
                        <span className="text-foreground">{e.message}</span>
                        <span className="text-[11px] text-muted-foreground">{friendly_time(e.created_at)}</span>
                    </div>
                }}
            </div>
        </div>}
    </section>;
}
