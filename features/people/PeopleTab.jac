"""Gabriel's workspace. Search and selection belong to this tab, not the shell."""
import from .Panels { PeoplePanel, ClaimsPanel }
import from .IdentityReview { IdentityReview }
import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot, PersonView }
sv import from ...walkers.resolve { DuplicateCandidate }

def:pub PeopleTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], onShowOnMap: Callable[[str], None] | None = None) -> JsxElement {
    has query: str = "", selectedId: str = "", reviewKey: str = "";
    q = query.strip().lower();
    people = [p for p in snapshot.people if q == "" or q in p.name.lower()];
    selected: PersonView | None = None;
    for p in people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(people) > 0 { selected = people[0]; }
    duplicates = [d for d in snapshot.duplicates if q == "" or q in d.person_a.lower() or q in d.person_b.lower()];

    # The open review is looked up from the live snapshot, so refresh updates it.
    matches: list[DuplicateCandidate] = [d for d in snapshot.duplicates if reviewKey != "" and (d.person_a_id + "|" + d.person_b_id) == reviewKey];
    personA: PersonView | None = None;
    personB: PersonView | None = None;
    reviewPanel: any = None;
    if len(matches) > 0 {
        review: DuplicateCandidate = matches[0];
        for p in snapshot.people {
            if p.id == review.person_a_id { personA = p; }
            if p.id == review.person_b_id { personB = p; }
        }
        reviewPanel = <IdentityReview candidate={review} personA={personA} personB={personB}
            onRefresh={onRefresh} onClose={lambda { reviewKey = ""; }} />;
    }

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
        {reviewPanel}
        <div className="grid items-start gap-8 xl:grid-cols-2">
            <PeoplePanel people={people} duplicates={duplicates}
                selectedId={selected.id if selected else ""}
                onSelect={lambda (pid: str) { selectedId = pid; }}
                onReview={lambda (key: str) { reviewKey = key; }} />
            <ClaimsPanel person={selected} onShowOnMap={onShowOnMap}
                mappedClaimIds={[e.claim_id for place in snapshot.locations for e in place.evidence]} />
        </div>
    </div>;
}
