"""Gabriel's workspace. Search and selection belong to this tab, not the shell."""
import from .Panels { PeoplePanel, ClaimsPanel }
import from .IdentityReview { IdentityReview }
import from .PeopleStats { PeopleStats }
import from .CorpusPeople { CorpusPeople }
import from ...components.shared.Display { SectionHeading }
import from ...components.shared.Scale { is_corpus_snapshot }
sv import from ...services.trace { DashboardSnapshot, PersonView, search_people }
sv import from ...walkers.resolve { DuplicateCandidate }

def:pub PeopleTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any], onShowOnMap: Callable[[str], None] | None = None, reviewRequest: int = 0) -> JsxElement {
    has query: str = "", selectedId: str = "", reviewKey: str = "",
        results: list[PersonView] | None = None, searching: bool = False,
        searchError: str = "", searchedFor: str = "";

    # A different incident starts with its own default list and no stale search.
    can with [snapshot.incident_id] entry {
        results = None;
        query = "";
        searchedFor = "";
        searchError = "";
        selectedId = "";
        reviewKey = "";
    }

    # The story guide asks to open a match review: prefer an undecided one.
    can with [reviewRequest] entry {
        if reviewRequest <= 0 or len(snapshot.duplicates) == 0 { return; }
        pending = [d for d in snapshot.duplicates if d.decision == "PENDING"];
        first = pending[0] if len(pending) > 0 else snapshot.duplicates[0];
        query = "";
        reviewKey = first.person_a_id + "|" + first.person_b_id;
    }

    async def runSearch -> None {
        term = query.strip();
        if term == "" {
            results = None;
            searchedFor = "";
            return;
        }
        searching = True;
        searchError = "";
        try {
            results = await search_people(snapshot.incident_id, term, 100);
            searchedFor = term;
        } except Exception as e {
            searchError = "Search failed: " + str(e);
        }
        searching = False;
    }

    raw: any = snapshot;
    corpus = is_corpus_snapshot(raw);
    if corpus {
        return <CorpusPeople snapshot={snapshot} people={results if results != None else snapshot.people}
            query={query} searching={searching} searchError={searchError} searchedFor={searchedFor}
            selectedId={selectedId} onSelect={lambda (pid: str) { selectedId = pid; }}
            onQuery={lambda (value: str) {
                query = value;
                if value.strip() == "" { results = None; searchedFor = ""; }
            }}
            onSearch={runSearch} onShowOnMap={onShowOnMap} />;
    }

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
        <SectionHeading title="People" subtitle="Find someone, see every report about them, and check possible matches." />
        <PeopleStats people={snapshot.people} duplicates={snapshot.duplicates} />
        <label className="flex max-w-xl flex-col gap-2 text-sm">
            <span className="font-medium">{"Search people"}</span>
            <input type="search" value={query}
                onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                placeholder="Type a name, for example Maya"
                className="h-11 w-full rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            <span className="text-xs text-muted-foreground">{str(len(people)) + " of " + str(len(snapshot.people)) + " people shown"}</span>
        </label>
        <div id="identity-review" className="scroll-mt-4">{reviewPanel}</div>
        <div className="grid items-start gap-8 xl:grid-cols-2">
            <PeoplePanel people={people} duplicates={duplicates}
                selectedId={selected.id if selected else ""}
                onSelect={lambda (pid: str) { selectedId = pid; }}
                onReview={lambda (key: str) { reviewKey = key; }} />
            <ClaimsPanel person={selected} incidentId={snapshot.incident_id} onShowOnMap={onShowOnMap}
                mappedClaimIds={[e.claim_id for place in snapshot.locations for e in place.evidence]} />
        </div>
    </div>;
}
