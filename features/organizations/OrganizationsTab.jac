"""Anshu's workspace. Current institutional sources projected from existing claims.

This does not create Organization nodes or infer that community posters are institutions.
Coordinate the future Organization -> Source relationship with the graph schema owner.
"""
import from ...components.shared.Display { SectionHeading, source_kind, status_sentence, friendly_time }
sv import from ...services.trace { DashboardSnapshot }

def:pub OrganizationsTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "";
    q = query.strip().lower();
    institutions: list[str] = [];
    for p in snapshot.people {
        for c in p.claims {
            if c.source_type in ["POLICE", "HOSPITAL", "NGO", "GOVERNMENT"] and c.source_name not in institutions {
                institutions.append(c.source_name);
            }
        }
    }
    visible = [name for name in institutions if q == "" or q in name.lower()];
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Organizations" subtitle="Read reports published by police, hospitals, government, and aid organizations." />
        <label className="flex max-w-xl flex-col gap-2 text-sm">
            <span className="font-medium">{"Search organizations"}</span>
            <input type="search" value={query}
                onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                placeholder="Search by organization name"
                className="h-11 rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
        </label>
        {len(visible) == 0 and <p className="rounded-md border border-dashed border-border p-6 text-sm text-muted-foreground">
            {"No institutional reports match this search."}
        </p>}
        <div className="grid items-start gap-4 xl:grid-cols-2">
            {for name in visible {
                <section key={name} className="flex flex-col gap-4 rounded-md border border-border bg-card p-4">
                    <h3 className="font-display text-xl">{name}</h3>
                    {for p in snapshot.people {
                        for c in p.claims {
                            if c.source_name == name {
                            <article key={c.id} className="flex flex-col gap-1 border-l-2 border-primary pl-3">
                                <span className="text-xs text-muted-foreground">{source_kind(c.source_type) + " · " + friendly_time(c.timestamp)}</span>
                                <span className="text-sm font-medium">{p.name + " · " + status_sentence(c.claim_type)}</span>
                                <p className="text-sm">{c.value}</p>
                                {c.notes and <p className="text-xs text-muted-foreground">{c.notes}</p>}
                            </article>
                            }
                        }
                    }}
                </section>
            }}
        </div>
    </div>;
}
