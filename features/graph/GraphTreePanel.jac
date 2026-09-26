"""Miguel owns the graph projection. Render existing relationships, never a second database."""
import from "@hugeicons/core-free-icons" { InformationCircleIcon }
import from ...components.shared.Display {
    SectionHeading, EmptyPanel, status_sentence, status_badge, source_kind
}
import from ...lib.utils { cn }
sv import from ...services.trace { PersonView }

# ---------------- How it connects (the graph, in plain words) ----------------
def Step(label: str, detail: str, tone: str = "") -> JsxElement {
    return <div className={cn("inline-flex flex-col rounded-md border border-border bg-card pt-1.5 pb-1.5 pl-2.5 pr-2.5 shadow-sm", tone)}>
        <span className="text-[11px] text-muted-foreground">{label}</span>
        <span className="text-sm font-medium">{detail}</span>
    </div>;
}

def Arrow(text: str) -> JsxElement {
    return <span className="text-xs text-muted-foreground">{text}</span>;
}

def:pub GraphTreePanel(incidentName: str, person: PersonView | None) -> JsxElement {
    if person == None {
        return <EmptyPanel icon={InformationCircleIcon} title="Choose a person" text="Select someone to see how the information about them connects." />;
    }
    return <section className="flex flex-col gap-3">
        <SectionHeading title="How the information connects" subtitle="Who reported what about this person, and who is following them." />
        <div className="flex flex-col gap-2 overflow-x-auto">
            <Step label="Disaster" detail={incidentName} />
            <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                <div className="flex flex-wrap items-center gap-2"><Arrow text="affected" /><Step label="Person" detail={person.name} tone="border-primary" /></div>
                <div className="ml-4 flex flex-col gap-2 border-l border-border pl-4">
                    {for c in person.claims {
                        <div key={c.id} className="flex flex-wrap items-center gap-2">
                            <Step label={source_kind(c.source_type)} detail={c.source_name} />
                            <Arrow text="says" />
                            <Step label="Report" detail={status_sentence(c.claim_type)} tone={status_badge(c.claim_type)} />
                        </div>
                    }}
                    {for s in person.subscriptions {
                        <div key={s.subscriber_name} className="flex flex-wrap items-center gap-2">
                            <Step label="Following" detail={s.subscriber_name} />
                            <Arrow text="received" />
                            <Step label="Notifications" detail={str(s.alert_count)} tone={"border-primary bg-primary/10" if s.alert_count > 0 else ""} />
                        </div>
                    }}
                </div>
            </div>
        </div>
    </section>;
}
