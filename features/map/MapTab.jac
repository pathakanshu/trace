"""Anshu's map workspace. Location pins come from the shared graph snapshot."""
import from .IncidentMap { IncidentMap }
import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot }

def:pub MapTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], active: bool = True) -> JsxElement {
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Map" subtitle="Explore places connected to this incident and its reports." />
        <div className="h-[60svh] min-h-96">
            <IncidentMap locations={snapshot.locations} active={active} />
        </div>
        <div className="flex flex-wrap justify-between gap-2 text-xs text-muted-foreground">
            <span>{"Shaded area: Sindhupalchok district. Pins show reported places, not people's live locations."}</span>
            <span>{str(len(snapshot.locations)) + " places in this incident"}</span>
        </div>
    </div>;
}
