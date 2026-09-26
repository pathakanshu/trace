"""Gabriel's workspace. Search and selection belong to this tab, not the shell."""
import from .Panels { PeoplePanel, ClaimsPanel }
import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot, PersonView }

def:pub PeopleTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "", selectedId: str = "";
    q = query.strip().lower();
    people = [p for p in snapshot.people if q == "" or q in p.name.lower()];
    selected: PersonView | None = None;
    for p in people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(people) > 0 { selected = people[0]; }
    duplicates = [d for d in snapshot.duplicates if q == "" or q in d.person_a.lower() or q in d.person_b.lower()];

    return <div className="flex flex-col gap-5">
        <SectionHeading title="People" subtitle="Find a case, compare source reports, and review possible identity matches." />
        <label className="flex max-w-xl flex-col gap-2 text-sm">
            <span className="font-medium">{"Search people"}</span>
            <input type="search" value={query}
                onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                placeholder="Type a name, for example Maya"
                className="h-11 w-full rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            <span className="text-xs text-muted-foreground">{str(len(people)) + " of " + str(len(snapshot.people)) + " people shown"}</span>
        </label>
        <div className="grid items-start gap-8 xl:grid-cols-2">
            <PeoplePanel people={people} duplicates={duplicates}
                selectedId={selected.id if selected else ""}
                onSelect={lambda (pid: str) { selectedId = pid; }} />
            <ClaimsPanel person={selected} />
        </div>
    </div>;
}
