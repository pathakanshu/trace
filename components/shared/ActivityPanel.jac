"""Shared in-app alerts and activity. Refreshed from the same dashboard snapshot."""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Notification01Icon }
import from .Display { SectionHeading, EmptyPanel, friendly_time }
sv import from ...services.trace { AlertView, ActivityView }

# ---------------- Notifications + recent updates ----------------
def:pub AlertsPanel(alerts: list[AlertView], activity: list[ActivityView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Notifications" subtitle="Sent to people following someone when new information arrives." />
        {len(alerts) == 0 and <EmptyPanel icon={Notification01Icon} title="No notifications yet" text="When a new report comes in about someone, their followers are notified here." />}
        {for a in alerts {
            <div key={a.created_at + a.message} className="flex items-start gap-3 rounded-md border border-primary/40 bg-primary/10 pt-3 pb-3 pl-3 pr-3 animate-in fade-in slide-in-from-bottom-2 duration-500">
                <HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0 text-primary" />
                <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">{"Sent to " + a.subscriber_name}</span>
                    <span className="text-sm text-muted-foreground">{a.message}</span>
                    <span className="text-[11px] text-muted-foreground">{friendly_time(a.created_at)}</span>
                </div>
            </div>
        }}
        <div className="flex flex-col gap-2 pt-2">
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
        </div>
    </section>;
}
