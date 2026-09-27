"""PFIF 1.4 import for organizations, with the accepted fields spelled out."""
import from ...components.ui.button { Button }
sv import from ...services.trace { DashboardSnapshot }
sv import from .pfif { import_pfif, PfifResult }

glob PFIF_EXAMPLE: str = """<?xml version="1.0" encoding="UTF-8"?>
<pfif:pfif xmlns:pfif="http://zesty.ca/pfif/1.4">
  <pfif:person>
    <pfif:person_record_id>shelter-desk.example/p-001</pfif:person_record_id>
    <pfif:full_name>Ram Thapa</pfif:full_name>
    <pfif:age>41</pfif:age>
    <pfif:note>
      <pfif:note_record_id>shelter-desk.example/n-001</pfif:note_record_id>
      <pfif:person_record_id>shelter-desk.example/p-001</pfif:person_record_id>
      <pfif:author_name>Family member (fictional)</pfif:author_name>
      <pfif:source_date>2026-09-20T09:00:00Z</pfif:source_date>
      <pfif:status>believed_missing</pfif:status>
      <pfif:last_known_location>Bahrabise bazaar</pfif:last_known_location>
      <pfif:text>Not heard from since the flood.</pfif:text>
    </pfif:note>
    <pfif:note>
      <pfif:note_record_id>shelter-desk.example/n-002</pfif:note_record_id>
      <pfif:person_record_id>shelter-desk.example/p-001</pfif:person_record_id>
      <pfif:author_name>Shelter volunteer (fictional)</pfif:author_name>
      <pfif:source_date>2026-09-21T11:30:00Z</pfif:source_date>
      <pfif:status>believed_alive</pfif:status>
      <pfif:text>Registered at the Khadichaur shelter.</pfif:text>
    </pfif:note>
  </pfif:person>
</pfif:pfif>""";

glob PFIF_MAPPING: list[list[str]] = [
    ["person_record_id", "Kept on every claim as the PFIF person id"],
    ["full_name, or given_name + family_name", "A new person record; names never merge with existing people"],
    ["age", "Person age (a range keeps its lower bound)"],
    ["note_record_id", "Report reference; re-importing the same note creates nothing"],
    ["status believed_missing", "Reported missing"],
    ["status believed_alive or is_note_author", "Reported safe"],
    ["status believed_dead", "Reported deceased"],
    ["last_known_location (no status)", "Seen at a location"],
    ["status information_sought, or none", "Skipped and listed, never guessed"],
    ["source_date, author_name, text", "Reported time, note author, summary; the full note XML is kept"]
];

def:pub PfifImport(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has organizationId: str = "", xmlText: str = "", busy: bool = False,
        result: any = None, error: str = "";

    async def run_import -> None {
        if not organizationId { error = "Choose the organization publishing these records."; return; }
        if not xmlText.strip() { error = "Paste PFIF XML or load the example."; return; }
        busy = True;
        error = "";
        result = None;
        try {
            response = await import_pfif(snapshot.incident_id, organizationId, xmlText);
            if not response { error = "No response received. Try again; repeated imports are safe."; }
            elif response.error { error = response.error; }
            else { result = response; await onRefresh(); }
        } except Exception {
            error = "The import could not run. Existing records have not changed.";
        }
        busy = False;
    }

    return <details className="min-w-0 break-words rounded-md border border-border bg-card p-4 md:p-5">
        <summary className="cursor-pointer">
            <span className="font-display text-2xl">{"Import PFIF records"}</span>
            <span className="ml-2 text-sm text-muted-foreground">{"People Finder Interchange Format 1.2 to 1.4, the format Google Person Finder imports and exports"}</span>
        </summary>
        <div className="mt-4 flex flex-col gap-4">
            <p className="max-w-3xl text-sm text-muted-foreground">{"Organizations can send missing-person records in PFIF XML. Each note becomes one sourced report under the organization you choose. Nothing is matched by name: a human confirms whether a PFIF person is someone already in Trace."}</p>
            <div className="overflow-x-auto">
                <table className="w-full min-w-[32rem] text-left text-sm">
                    <thead><tr className="border-b border-border text-xs text-muted-foreground"><th className="py-2 pr-4 font-medium">{"PFIF field"}</th><th className="py-2 font-medium">{"What Trace records"}</th></tr></thead>
                    <tbody>{for row in PFIF_MAPPING {
                        <tr key={row[0]} className="border-b border-border/60"><td className="py-2 pr-4 font-mono text-xs">{row[0]}</td><td className="py-2">{row[1]}</td></tr>
                    }}</tbody>
                </table>
            </div>
            <p className="text-xs text-muted-foreground">{"Limits: 200,000 characters per import; DOCTYPE and ENTITY declarations are refused. Photos, linked records and expiry dates are not imported yet."}</p>
            <div className="flex flex-wrap items-end gap-3">
                <label className="flex min-w-56 flex-col gap-1 text-sm">
                    <span>{"Publishing organization"}</span>
                    <select value={organizationId} disabled={busy} onChange={lambda (e: ChangeEvent) { organizationId = e.target.value; }} className="h-11 rounded-md border border-input bg-background px-3">
                        <option value="">{"Choose an organization"}</option>
                        {for org in snapshot.organizations { <option key={org.id} value={org.id}>{org.name}</option> }}
                    </select>
                </label>
                <Button variant="outline" size="sm" disabled={busy} onClick={lambda { xmlText = PFIF_EXAMPLE; result = None; error = ""; }}>{"Load PFIF example"}</Button>
            </div>
            <label className="flex flex-col gap-1 text-sm">
                <span>{"PFIF XML"}</span>
                <textarea value={xmlText} disabled={busy} spellCheck={False} onChange={lambda (e: ChangeEvent) { xmlText = e.target.value; }} placeholder={"<pfif:pfif xmlns:pfif='http://zesty.ca/pfif/1.4'> ..."} className="min-h-48 rounded-md border border-input bg-background p-3 font-mono text-xs" />
            </label>
            <div><Button disabled={busy} onClick={run_import}>{"Importing..." if busy else "Import PFIF records"}</Button></div>
            {error and <p role="alert" className="text-sm text-destructive">{error}</p>}
            {result and <div role="status" className="rounded-md border border-border bg-muted/30 p-3 text-sm">
                <p>{str(result.claims_created) + " report(s) created for " + str(result.people) + " person record(s); " + str(result.duplicates) + " already imported; WatchWalker created " + str(result.alerts_created) + " alert(s)."}</p>
                {len(result.skipped) > 0 and <ul className="mt-2 list-disc pl-5 text-xs text-muted-foreground">{for item in result.skipped { <li key={item}>{"Skipped " + item}</li> }}</ul>}
            </div>}
        </div>
    </details>;
}
