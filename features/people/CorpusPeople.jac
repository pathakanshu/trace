"""People view for a large incident: status totals, a capped list, server search.

The corpus snapshot lists at most 100 people, so filtering in the browser would
only search that page. Search here asks the server (search_people) instead.
Identity review and the report checker stay with the demo incident.
"""
import from .Panels { PeoplePanel, ClaimsPanel }
import from ...components.shared.Display { SectionHeading, status_dot }
import from ...components.shared.Scale { count_of, status_key_label, fmt_count }
import from ...lib.utils { cn }
sv import from ...services.trace { DashboardSnapshot, PersonView }

def:pub CorpusPeople(
    snapshot: DashboardSnapshot,
    people: list[PersonView],
    query: str,
    searching: bool,
    searchError: str,
    searchedFor: str,
    selectedId: str,
    onSelect: Callable[[str], None],
    onQuery: Callable[[str], None],
    onSearch: Callable[[], any],
    onShowOnMap: Callable[[str], None] | None = None
) -> JsxElement {
    raw: any = snapshot;
    counts: any = raw.status_counts;
    keys: list[str] = counts.keys() if counts else [];
    ordered = [k for k in ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED", "SEEN_AT_LOCATION"] if k in keys];
    ordered = ordered + [k for k in keys if k not in ordered];
    total: int = raw.people_total or len(snapshot.people);

    selected: PersonView | None = None;
    for p in people {
        if p.id == selectedId { selected = p; }
    }
    if selected == None and len(people) > 0 { selected = people[0]; }

    def submit(event: any) -> None {
        event.preventDefault();
        onSearch();
    }

    return <div className="flex min-w-0 flex-col gap-5">
        <SectionHeading title="People" subtitle="Generated exercise records. Search by name to find anyone beyond the first page." />
        {len(ordered) > 0 and <ul aria-label="People by latest reported status" className="flex flex-wrap gap-2">
            {for k in ordered {
                <li key={k} className="flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1 text-sm">
                    <span className={cn("size-2.5 shrink-0 rounded-full", status_dot(k))} />
                    <span>{status_key_label(k)}</span>
                    <span className="font-medium tabular-nums">{fmt_count(count_of(counts, k))}</span>
                </li>
            }}
        </ul>}
        <form role="search" onSubmit={submit} className="flex max-w-xl flex-col gap-2 text-sm">
            <label htmlFor="corpus-people-search" className="font-medium">{"Search all people"}</label>
            <div className="flex gap-2">
                <input id="corpus-people-search" type="search" value={query}
                    onChange={lambda (e: ChangeEvent) { onQuery(e.target.value); }}
                    placeholder="Type a name, then press Enter"
                    className="h-11 min-w-0 flex-1 rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                <button type="submit" disabled={searching}
                    className="h-11 shrink-0 rounded-md border border-border bg-primary px-4 text-sm font-medium text-primary-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60">
                    {"Searching..." if searching else "Search"}
                </button>
            </div>
            <span role="status" className="text-xs text-muted-foreground">
                {("Showing " + fmt_count(len(people)) + " match" + ("" if len(people) == 1 else "es") + " for \"" + searchedFor + "\" (up to 100). Clear the box to return to the list.")
                    if searchedFor else ("Showing " + fmt_count(len(people)) + " of " + fmt_count(total) + " people")}
            </span>
            {searchError and <span role="alert" className="text-xs text-destructive">{searchError}</span>}
        </form>
        <div className="grid items-start gap-8 xl:grid-cols-2">
            <PeoplePanel people={people} duplicates={[]}
                selectedId={selected.id if selected else ""}
                onSelect={onSelect}
                onReview={onSelect} />
            <ClaimsPanel person={selected} onShowOnMap={onShowOnMap}
                mappedClaimIds={[e.claim_id for place in snapshot.locations for e in place.evidence]} />
        </div>
    </div>;
}
