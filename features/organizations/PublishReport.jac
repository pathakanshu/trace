"""Small structured form: review locally, then publish one sourced graph claim."""
import from ...components.ui.button { Button }
import from ...components.shared.Display { status_sentence }
import from ...components.shared.EditLock { edit_key }
sv import from ...services.trace { DashboardSnapshot }
sv import from .services { publish_report }

def:pub PublishReport(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has organizationId: str = "", personId: str = "", claimType: str = "FOUND_SAFE",
        summary: str = "", reportedAt: str = "", reference: str = "", original: str = "",
        reviewing: bool = False, busy: bool = False, error: str = "", notice: str = "";
    organizations = snapshot.organizations;
    organization = [o for o in organizations if o.id == organizationId];
    person = [p for p in snapshot.people if p.id == personId];
    selectedOrg = organization[0] if organization else None;
    selectedPerson = person[0] if person else None;

    can with [snapshot.incident_id] entry {
        organizationId = "";
        personId = "";
        reviewing = False;
        notice = "";
        error = "";
    }
    def loadExample -> None;
    def review(event: any) -> None;
    async def publish -> None;

    return <section className="min-w-0 break-words rounded-md border border-border bg-card p-4 md:p-5">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
            <div>
                <h3 className="font-display text-2xl">{"Publish a report"}</h3>
                <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{"Fictional institutions only. This selector does not verify an organization's identity. Every report keeps its source and history."}</p>
            </div>
            <Button variant="outline" size="sm" disabled={busy} onClick={loadExample}>{"Load hospital example"}</Button>
        </div>
        {len(organizations) == 0 and <p className="mb-3 text-sm text-status-warning">{"No institutions yet. Use Start over in Maya's story to load them."}</p>}
        <form onSubmit={review} className="flex flex-col gap-4">
            <fieldset disabled={busy or reviewing} className="grid min-w-0 gap-4 md:grid-cols-2 disabled:opacity-70">
                <label className="flex min-w-0 flex-col gap-1 text-sm">
                    <span>{"Organization"}</span>
                    <select required value={organizationId} onChange={lambda (e: ChangeEvent) { organizationId = e.target.value; }} className="h-11 w-full rounded-md border border-input bg-background px-3">
                        <option value="">{"Choose an organization"}</option>
                        {for org in organizations { <option key={org.id} value={org.id}>{org.name}</option> }}
                    </select>
                </label>
                <label className="flex min-w-0 flex-col gap-1 text-sm">
                    <span>{"Person record"}</span>
                    <select required value={personId} onChange={lambda (e: ChangeEvent) { personId = e.target.value; }} className="h-11 w-full rounded-md border border-input bg-background px-3">
                        <option value="">{"Choose an existing record"}</option>
                        {for p in snapshot.people { <option key={p.id} value={p.id}>{p.name + " · age " + (str(p.age) if p.age else "unknown") + " · record " + p.id[-6:]}</option> }}
                    </select>
                </label>
                <label className="flex flex-col gap-1 text-sm">
                    <span>{"Reported status"}</span>
                    <select value={claimType} onChange={lambda (e: ChangeEvent) { claimType = e.target.value; }} className="h-11 rounded-md border border-input bg-background px-3">
                        {for status in ["FOUND_SAFE", "MISSING", "INJURED", "DECEASED", "SEEN_AT_LOCATION"] { <option key={status} value={status}>{status_sentence(status)}</option> }}
                    </select>
                </label>
                <label className="flex flex-col gap-1 text-sm">
                    <span>{"Reported time (UTC, optional)"}</span>
                    <input type="datetime-local" value={reportedAt} onChange={lambda (e: ChangeEvent) { reportedAt = e.target.value; }} className="h-11 min-w-0 rounded-md border border-input bg-background px-3" />
                    <span className="text-xs text-muted-foreground">{"Leave blank if unknown; ingestion time is recorded separately."}</span>
                </label>
                <label className="flex flex-col gap-1 text-sm md:col-span-2">
                    <span>{"Report reference"}</span>
                    <input required maxLength={300} value={reference} onChange={lambda (e: ChangeEvent) { reference = e.target.value; }} placeholder="An institution's report ID or source reference" className="h-11 rounded-md border border-input bg-background px-3" />
                    <span className="text-xs text-muted-foreground">{"Retry with the same reference. Corrections need a new reference and retain the earlier report."}</span>
                </label>
                <label className="flex flex-col gap-1 text-sm md:col-span-2">
                    <span>{"Report summary"}</span>
                    <input required maxLength={2000} value={summary} onChange={lambda (e: ChangeEvent) { summary = e.target.value; }} className="h-11 rounded-md border border-input bg-background px-3" />
                </label>
                <label className="flex flex-col gap-1 text-sm md:col-span-2">
                    <span>{"Original report text"}</span>
                    <textarea required rows={3} maxLength={10000} value={original} onChange={lambda (e: ChangeEvent) { original = e.target.value; }} className="rounded-md border border-input bg-background p-3" />
                </label>
            </fieldset>
            {not reviewing and <div><Button type="submit" disabled={busy or len(organizations) == 0}>{"Review report"}</Button></div>}
        </form>
        {reviewing and <div className="mt-4 flex min-w-0 flex-col gap-3 rounded-md border border-primary/40 bg-accent/30 p-4" aria-label="Report preview">
            <h4 className="font-medium">{"Review before publishing"}</h4>
            <p className="text-sm">{(selectedOrg.name if selectedOrg else "Unknown institution") + " reports " + (selectedPerson.name if selectedPerson else "Unknown person") + " as " + status_sentence(claimType) + "."}</p>
            <p className="text-sm">{summary}</p>
            <p className="text-xs text-muted-foreground">{"Reference: " + reference + " · Reported: " + (reportedAt + " UTC" if reportedAt else "unknown")}</p>
            <p className="whitespace-pre-wrap text-sm">{original}</p>
            <p className="text-xs text-muted-foreground">{"This adds a source claim and checks subscriptions for updates. Earlier reports stay available."}</p>
            <div className="flex flex-wrap gap-2">
                <Button disabled={busy} onClick={publish}>{"Publishing..." if busy else "Publish report"}</Button>
                <Button variant="outline" disabled={busy} onClick={lambda { reviewing = False; }}>{"Edit report"}</Button>
            </div>
        </div>}
        {error and <p role="alert" className="mt-3 text-sm text-destructive">{error}</p>}
        {notice and <p role="status" className="mt-3 break-words text-sm text-status-safe">{notice}</p>}
    </section>;
}
