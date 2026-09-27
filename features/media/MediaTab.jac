import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot }
sv import from .media_upload { UploadRecord, upload_image, list_incident_media, check_media_duplicates, edit_media, delete_media, add_media_comment, add_media_assertion }
import from ...components.ui.button { Button }

# A single card and persistent controls for one canonical Media node.
def:pub MediaRecordCard(item: UploadRecord, onRefresh: Callable[[], any], readOnly: bool = False) -> JsxElement {
    has editing: bool = False, title: str = item.display_name,
        source: str = item.source_reference, description: str = item.description,
        comment: str = "", author: str = "", claim_value: str = "",
        claim_source: str = "", claim_provenance: str = "", busy: bool = False,
        error: str = "", confirm_delete: bool = False,
        comments_open: bool = False, claims_open: bool = False,
        comment_form_open: bool = False, claim_form_open: bool = False;

    async def save_edit {
        busy = True;
        try {
            await edit_media(item.id, item.incident, title, source, description);
            editing = False;
            await onRefresh();
        } except Exception as e { error = "Could not save media details: " + str(e); }
        busy = False;
    }
    async def save_comment {
        if not comment.strip() { error = "Write a comment first."; return; }
        busy = True;
        try {
            await add_media_comment(item.id, item.incident, comment, author);
            comment = "";
            await onRefresh();
        } except Exception as e { error = "Could not add comment: " + str(e); }
        busy = False;
    }
    async def save_assertion {
        if not claim_value.strip() or not claim_source.strip() {
            error = "Enter the reported location/source and its source.";
            return;
        }
        busy = True;
        try {
            await add_media_assertion(item.id, item.incident, "LOCATION_OR_SOURCE", claim_value, claim_source, claim_provenance);
            claim_value = "";
            claim_source = "";
            claim_provenance = "";
            await onRefresh();
        } except Exception as e { error = "Could not add claim: " + str(e); }
        busy = False;
    }
    async def remove_record {
        busy = True;
        try {
            removed = await delete_media(item.id, item.incident);
            if removed { confirm_delete = False; await onRefresh(); }
            else { error = "This media item was not found in the selected incident."; }
        } except Exception as e { error = "Could not delete media: " + str(e); }
        busy = False;
    }

    return <article className="flex min-w-0 flex-col gap-3 rounded-xl border bg-card p-4 shadow-sm">
        {item.data_url.startswith("data:image/") and <img src={item.data_url} alt={item.display_name} className="h-48 w-full rounded-lg bg-muted object-contain" />}
        {item.data_url and not item.data_url.startswith("data:image/") and <div className="flex h-24 items-center justify-center rounded-lg border border-dashed bg-muted/30 p-3 text-center text-xs text-muted-foreground">{"Preview unavailable: the file " + item.data_url + " is not bundled with this demo. The record and its links are kept."}</div>}
        <div className="flex flex-wrap items-start justify-between gap-2">
            <div className="min-w-0"><h3 className="break-words text-base font-semibold">{item.display_name}</h3>
                <p className="text-xs text-muted-foreground">{item.filename + " · " + item.incident}</p></div>
            {item.sha256 and <div className="flex gap-2"><Button size="sm" variant="outline" onClick={lambda { editing = not editing; }}>Edit</Button>
                <Button size="sm" variant="destructive" onClick={lambda { confirm_delete = True; }}>Delete</Button></div>}
        </div>
        {editing and <div className="flex flex-col gap-2 rounded-lg bg-muted/30 p-3">
            <label className="flex flex-col gap-1 text-xs font-medium">Display name<input value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} className="h-9 rounded-md border border-input bg-background px-3 text-sm" /></label>
            <label className="flex flex-col gap-1 text-xs font-medium">Source or reference<input value={source} onChange={lambda (e: ChangeEvent) { source = e.target.value; }} className="h-9 rounded-md border border-input bg-background px-3 text-sm" /></label>
            <label className="flex flex-col gap-1 text-xs font-medium">Description<textarea value={description} onChange={lambda (e: ChangeEvent) { description = e.target.value; }} className="min-h-16 rounded-md border border-input bg-background p-2 text-sm" /></label>
            <Button size="sm" onClick={save_edit} disabled={busy}>Save media details</Button>
        </div>}
        <p className="break-all text-xs text-muted-foreground">{"Source/reference: " + (item.source_reference if item.source_reference else "Not supplied")}</p>
        <p className="whitespace-pre-wrap text-sm">{item.description}</p>
        {not item.sha256 and not readOnly and <p className="text-xs text-muted-foreground">Seeded demonstration record; no uploaded file was analyzed.</p>}
        {readOnly and <p className="text-xs text-muted-foreground">Generated exercise record: metadata only. The image file is not imported, so nothing was analyzed.</p>}
        {item.sha256 and <p className="break-all font-mono text-xs text-muted-foreground">{"SHA-256: " + item.sha256}</p>}
        {len(item.duplicate_ids) > 0 and <div className="rounded-md bg-muted p-3 text-xs"><p className="font-semibold">{"Exact duplicate matches: " + str(len(item.duplicate_ids))}</p><p className="mt-1">Byte-identical copies are not independent corroboration.</p><p className="mt-1">{"Related media IDs: " + ", ".join(item.duplicate_ids)}</p></div>}
        <section className="border-t pt-2">
            <button type="button" onClick={lambda { comments_open = not comments_open; }} aria-expanded={comments_open} className="flex w-full items-center justify-between rounded-md px-2 py-2 text-left text-sm font-medium transition-colors hover:bg-muted/50">
                <span>{"Comments (" + str(len(item.comments)) + ")"}</span><span className="text-muted-foreground">{"⌄" if comments_open else "›"}</span>
            </button>
            {comments_open and <div className="flex flex-col gap-2 px-2 pb-2">
                {for c in item.comments {<div key={c.id} className="rounded-md bg-muted/40 p-2"><p className="whitespace-pre-wrap text-sm">{c.body}</p><p className="mt-1 text-xs text-muted-foreground">{c.author + " · " + c.created_at}</p></div>}}
                {not readOnly and not comment_form_open and <Button size="sm" variant="outline" onClick={lambda { comment_form_open = True; }}>+ Add comment</Button>}
                {comment_form_open and <div className="flex flex-col gap-2 rounded-md bg-muted/30 p-2">
                    <input value={author} onChange={lambda (e: ChangeEvent) { author = e.target.value; }} placeholder="Your name or source" className="h-9 rounded-md border border-input bg-background px-3 text-sm" />
                    <textarea value={comment} onChange={lambda (e: ChangeEvent) { comment = e.target.value; }} placeholder="Add a comment" className="min-h-16 rounded-md border border-input bg-background p-2 text-sm" />
                    <div className="flex justify-end gap-2"><Button size="sm" variant="outline" onClick={lambda { comment = ""; comment_form_open = False; }}>Cancel</Button><Button size="sm" onClick={save_comment} disabled={busy}>Save comment</Button></div>
                </div>}
            </div>}
        </section>
        <section className="border-t pt-2">
            <button type="button" onClick={lambda { claims_open = not claims_open; }} aria-expanded={claims_open} className="flex w-full items-center justify-between rounded-md px-2 py-2 text-left text-sm font-medium transition-colors hover:bg-muted/50">
                <span>{"Claims (" + str(len(item.assertions)) + ")"}</span><span className="text-muted-foreground">{"⌄" if claims_open else "›"}</span>
            </button>
            {claims_open and <div className="flex flex-col gap-2 px-2 pb-2">
                {for claim in item.assertions {<div key={claim.id} className="rounded-md bg-muted/40 p-2"><p className="text-sm">{claim.value}</p><p className="mt-1 text-xs text-muted-foreground">{claim.source + " · " + claim.asserted_at + " · " + claim.status}</p><p className="text-xs text-muted-foreground">{claim.provenance}</p></div>}}
                {not readOnly and not claim_form_open and <Button size="sm" variant="outline" onClick={lambda { claim_form_open = True; }}>+ Add claim</Button>}
                {claim_form_open and <div className="flex flex-col gap-2 rounded-md bg-muted/30 p-2">
                    <input value={claim_value} onChange={lambda (e: ChangeEvent) { claim_value = e.target.value; }} placeholder="Reported place or source" className="h-9 rounded-md border border-input bg-background px-3 text-sm" />
                    <input value={claim_source} onChange={lambda (e: ChangeEvent) { claim_source = e.target.value; }} placeholder="Who reported this?" className="h-9 rounded-md border border-input bg-background px-3 text-sm" />
                    <input value={claim_provenance} onChange={lambda (e: ChangeEvent) { claim_provenance = e.target.value; }} placeholder="Provenance or context" className="h-9 rounded-md border border-input bg-background px-3 text-sm" />
                    <p className="text-xs text-muted-foreground">Claims are attributed reports, not verified location facts.</p>
                    <div className="flex justify-end gap-2"><Button size="sm" variant="outline" onClick={lambda { claim_value = ""; claim_source = ""; claim_provenance = ""; claim_form_open = False; }}>Cancel</Button><Button size="sm" onClick={save_assertion} disabled={busy}>Save claim</Button></div>
                </div>}
            </div>}
        </section>
        {confirm_delete and <div role="alertdialog" className="flex flex-wrap items-center gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm"><span className="mr-auto">Delete this media item and its comments, claims, signals, and duplicate links?</span><Button size="sm" variant="outline" onClick={lambda { confirm_delete = False; }}>Cancel</Button><Button size="sm" variant="destructive" onClick={remove_record} disabled={busy}>Confirm delete</Button></div>}
        {error and <p role="alert" className="text-sm text-destructive">{error}</p>}
    </article>;
}

def:pub MediaTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "",
        source: str = "", selected_name: str = "", preview: str = "",
        busy: bool = False, error: str = "", notice: str = "";
    incident = snapshot.incident_name;
    media_items = snapshot.media_records;

    async def refresh_media {
        await onRefresh();
    }
    def handle_file(e: ChangeEvent) {
        file: any = e.target.files[0];
        if file {
            if not file.type.startswith("image/") { error = "Choose a PNG, JPEG, GIF, or WebP image."; return; }
            if file.size > 6_000_000 { error = "Choose an image under 6 MB."; return; }
            selected_name = str(file.name);
            # jac:ignore[W2001,E1053]
            reader: any = new((window as any).FileReader);
            reader.onload = lambda (event: any) { preview = event.target.result; error = ""; };
            reader.onerror = lambda (event: any) { error = "The browser could not read this image. Choose it again."; };
            reader.readAsDataURL(file);
        }
    }
    async def do_upload {
        if not incident.strip() { error = "Choose the incident before uploading."; return; }
        if not source.strip() { error = "Enter the supplied source or reference."; return; }
        if not preview { error = "Choose an image to preview before uploading."; return; }
        busy = True;
        try {
            await upload_image(incident, selected_name, source, preview);
            preview = ""; selected_name = ""; source = "";
            notice = "Image saved as a Media record. Exact matches use SHA-256 within this incident.";
            await refresh_media();
        } except Exception as e { error = "Upload failed: " + str(e); }
        busy = False;
    }
    async def do_duplicate_check {
        busy = True;
        try {
            await check_media_duplicates(incident);
            notice = "Exact duplicate relationships refreshed for this incident.";
            await onRefresh();
        } except Exception as e { error = "Duplicate check failed: " + str(e); }
        busy = False;
    }

    q = query.strip().lower();
    records = [m for m in media_items
        if q == "" or q in m.filename.lower() or q in m.display_name.lower()
        or q in m.source_reference.lower() or q in m.description.lower()
        or q in m.incident.lower() or q in ", ".join([a.value + " " + a.source for a in m.assertions]).lower()
        or q in ", ".join([c.body + " " + c.author for c in m.comments]).lower()];

    return <div className="flex flex-col gap-5">
        <SectionHeading title="Incident media" subtitle="One incident-scoped collection for uploaded files, seeded media, sources, comments, and attributed claims." />
        {snapshot.is_corpus and <p className="rounded-md border border-border bg-muted/30 p-3 text-sm text-muted-foreground">{str(len(media_items)) + " generated exercise media records with their descriptions and captions. Image files are not imported, so uploads, duplicate checks and edits are off for this incident."}</p>}
        {not snapshot.is_corpus and <section className="grid gap-4 rounded-xl border bg-card p-4 shadow-sm md:grid-cols-2 md:p-6">
            <div className="flex flex-col gap-3">
                <h2 className="text-lg font-semibold">Upload an image</h2>
                <p className="text-sm text-muted-foreground">Uploads become canonical Media records. SHA-256 is calculated from image bytes on the server.</p>
                <label className="flex flex-col gap-1 text-sm font-medium">Incident<input value={incident} readOnly={True} className="h-10 rounded-md border bg-muted px-3 font-normal" /></label>
                <label className="flex flex-col gap-1 text-sm font-medium">Supplied source/reference<input value={source} onChange={lambda (e: ChangeEvent) { source = e.target.value; }} placeholder="Reporter, URL, or source note" className="h-10 rounded-md border border-input bg-background px-3 font-normal" /></label>
                <label className="flex flex-col gap-1 text-sm font-medium">Image file<input type="file" accept="image/png,image/jpeg,image/gif,image/webp" onChange={handle_file} className="rounded-md border p-2 text-sm" /></label>
                {selected_name and <p className="text-xs text-muted-foreground">{selected_name}</p>}
                <Button onClick={do_upload} disabled={busy}>Upload to incident media</Button>
            </div>
            <div className="flex min-h-48 items-center justify-center rounded-lg border border-dashed bg-muted/30 p-3">
                {preview and <img src={preview} alt="Selected image preview" className="max-h-72 max-w-full object-contain" />}
                {not preview and <p className="text-sm text-muted-foreground">Choose an image to preview it before upload.</p>}
            </div>
        </section>}
        {error and <p role="alert" className="rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm text-destructive">{error}</p>}
        {notice and <p role="status" className="rounded-md border border-primary/30 bg-primary/5 p-3 text-sm">{notice}</p>}
        <section className="flex flex-col gap-4 rounded-xl border bg-card p-4 shadow-sm md:p-6">
            <div className="flex flex-wrap items-end justify-between gap-3">
                <div><h2 className="text-lg font-semibold">Media collection</h2><p className="text-sm text-muted-foreground">Search filename, display name, source, description, claim, or comment.</p></div>
                {not snapshot.is_corpus and <Button variant="outline" onClick={do_duplicate_check} disabled={busy}>Check exact duplicates</Button>}
            </div>
            <input type="search" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }} placeholder="Search this incident's media" className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:ring-2 focus-visible:ring-ring" />
                {records == [] and <div className="rounded-lg border border-dashed bg-muted/20 p-8 text-center"><h3 className="font-medium">No matching media</h3><p className="mt-1 text-sm text-muted-foreground">Upload an image or change the search.</p></div>}
            <div className="grid gap-4 lg:grid-cols-2">{for item in records {<MediaRecordCard key={item.id} item={item} onRefresh={refresh_media} readOnly={snapshot.is_corpus} />}}</div>
        </section>
    </div>;
}
