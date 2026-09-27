"""Anshu: institutional reports and a structured, reviewed publishing form."""
import from .PublishReport { PublishReport }
import from .PfifImport { PfifImport }
import from ...components.shared.Display { SectionHeading, source_kind, status_sentence, friendly_time }
import from ...components.shared.Scale { is_corpus_snapshot, fmt_count, org_type_label }
sv import from ...services.trace { DashboardSnapshot, OrganizationView }

# Corpus view: every publisher with its report count, busiest first. The
# publishing form targets the demo incident, so it is not offered here.
def:pub CorpusOrganizations(snapshot: DashboardSnapshot, query: str, onQuery: Callable[[str], None]) -> JsxElement {
    q = query.strip().lower();
    orgs = [o for o in snapshot.organizations if q == "" or q in o.name.lower()];
    orgs.sort(key=lambda (o: OrganizationView) -> int { return 0 - (o.report_count or 0); });
    return <div className="flex min-w-0 flex-col gap-5">
        <SectionHeading title="Sources"
            subtitle={fmt_count(len(snapshot.organizations)) + " publishers in the generated exercise corpus, ordered by how many source reports each one published."} />
        <label className="flex max-w-xl flex-col gap-2 text-sm">
            <span className="font-medium">{"Search organizations"}</span>
            <input type="search" value={query}
                onChange={lambda (e: ChangeEvent) { onQuery(e.target.value); }}
                placeholder="Search by organization name"
                className="h-11 rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
        </label>
        {len(orgs) == 0 and <p className="rounded-md border border-dashed border-border p-6 text-sm text-muted-foreground">{"No organizations match this search."}</p>}
        <ol className="flex flex-col divide-y divide-border rounded-md border border-border bg-card">
            {for o in orgs {
                <li key={o.id} className="flex min-w-0 items-center justify-between gap-3 px-3 py-2.5">
                    <div className="flex min-w-0 flex-col">
                        <span className="break-words text-sm font-medium">{o.name}</span>
                        <span className="text-xs text-muted-foreground">{org_type_label(o.organization_type)}</span>
                    </div>
                    <span className="shrink-0 text-right text-sm tabular-nums">
                        <span className="font-display text-lg">{fmt_count(o.report_count or 0)}</span>
                        <span className="text-xs text-muted-foreground">{" reports"}</span>
                    </span>
                </li>
            }}
        </ol>
    </div>;
}

def:pub OrganizationsTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "";
    raw: any = snapshot;
    if is_corpus_snapshot(raw) {
        return <CorpusOrganizations snapshot={snapshot} query={query} onQuery={lambda (v: str) { query = v; }} />;
    }
    q = query.strip().lower();
    institutions = [o.name for o in snapshot.organizations];
    visible = [name for name in institutions if q == "" or q in name.lower()];
    return <div className="flex min-w-0 flex-col gap-5">
        <SectionHeading title="Sources" subtitle="Reports published by police, hospitals, government and aid groups. Each one keeps its original text." />
        <PublishReport snapshot={snapshot} onRefresh={onRefresh} />
        <PfifImport snapshot={snapshot} onRefresh={onRefresh} />
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
                <section key={name} className="flex min-w-0 flex-col gap-4 break-words rounded-md border border-border bg-card p-4">
                    <h3 className="font-display text-xl">{name}</h3>
                    {for p in snapshot.people {
                        for c in p.claims {
                            if c.source_name == name {
                            <article key={c.id} className="flex min-w-0 flex-col gap-1 border-l-2 border-primary pl-3">
                                <span className="text-xs text-muted-foreground">{source_kind(c.source_type) + " · " + friendly_time(c.timestamp)}</span>
                                <span className="text-sm font-medium">{p.name + " · " + status_sentence(c.claim_type)}</span>
                                <p className="text-sm">{c.value}</p>
                                <p className="text-xs text-muted-foreground">{"Report: " + (c.source_reference or "unknown reference") + " · Ingested: " + (c.ingested_at or "unknown")}</p>
                                <details className="text-xs">
                                    <summary className="cursor-pointer text-primary">{"Source record and original text"}</summary>
                                    <p className="mt-2 whitespace-pre-wrap">{c.original_content or "Original text not recorded in this legacy fixture."}</p>
                                    <p className="mt-2 break-all text-muted-foreground">{"Claim: " + c.id + " · Source: " + c.source_id + " · Method: " + (c.extraction_method or "unknown")}</p>
                                </details>
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
