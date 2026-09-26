"""Miguel's workspace. Uses the same reports and relationships as the other tabs."""
import from .GraphTreePanel { GraphTreePanel }
import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot, PersonView }

def:pub GraphTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has selectedId: str = "";
    selected: PersonView | None = None;
    for p in snapshot.people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(snapshot.people) > 0 { selected = snapshot.people[0]; }
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Graph" subtitle="Follow the connections between sources, reports, people, and notifications." />
        <label className="flex max-w-xl flex-col gap-2 text-sm">
            <span className="font-medium">{"Explore connections for"}</span>
            <select value={selected.id if selected else ""}
                onChange={lambda (e: ChangeEvent) { selectedId = e.target.value; }}
                className="h-11 rounded-md border border-input bg-card px-3 text-foreground focus-visible:ring-2 focus-visible:ring-ring">
                {for p in snapshot.people { <option key={p.id} value={p.id}>{p.name}</option> }}
            </select>
        </label>
        <GraphTreePanel incidentName={snapshot.incident_name} person={selected} />
    </div>;
}
