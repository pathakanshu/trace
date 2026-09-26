import from .EvidencePanel { EvidencePanel }
import from ...components.shared.Display { SectionHeading }
import from ...services.trace { DashboardSnapshot }
import from .media_upload { UploadRecord, upload_image, list_image_uploads, check_media_duplicates }
import from ...components.ui.button { Button }

def:pub DuplicateDetails(item: UploadRecord, uploads: list[UploadRecord]) -> JsxElement {
    matches = [other for other in uploads if other.id in item.duplicate_ids];
    return <div className="rounded-md bg-muted p-2 text-xs">
        <p className="font-semibold">{"Exact duplicate matches: " + str(len(item.duplicate_ids))}</p>
        <p className="mt-1">Byte-identical copies are not independent corroboration.</p>
        {for other in matches {
            <p key={other.id} className="mt-1 break-all">{other.filename + " · " + other.source_reference + " · " + other.uploaded_at}</p>
        }}
    </div>;
}

# The upload panel is isolated from the shared snapshot: media uploads persist in their own graph records.
def:pub MediaTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "", mediaType: str = "all";
    has incident: str = "", source: str = "", selected_name: str = "";
    has preview: str = "", uploads: list[UploadRecord] = [];
    has busy: bool = False, loading_records: bool = False, error: str = "", notice: str = "";

    async can with entry {
        initial_incident = incident;
        if len(snapshot.media) > 0 {
            initial_incident = snapshot.incident_name;
            incident = initial_incident;
        }
        if initial_incident.strip() {
            loading_records = True;
            try {
                uploads = await list_image_uploads(initial_incident);
                error = "";
            } except Exception as e {
                error = "Could not load saved uploads: " + str(e);
            }
            loading_records = False;
        }
    }

    def handle_file(e: ChangeEvent) {
        file: any = e.target.files[0];
        if file {
            if not file.type.startswith("image/") {
                error = "Choose a PNG, JPEG, GIF, or WebP image.";
                return;
            }
            if file.size > 6_000_000 {
                error = "This image is too large. Choose an image under 6 MB.";
                return;
            }
            selected_name = str(file.name);
            # jac:ignore[W2001,E1053]
            reader: any = new((window as any).FileReader);
            reader.onload = lambda (event: any) {
                preview = event.target.result;
                error = "";
            };
            reader.onerror = lambda (event: any) {
                error = "The browser could not read this image. Choose it again.";
            };
            reader.readAsDataURL(file);
        }
    }

    async def handle_upload -> None {
        error = "";
        notice = "";
        if busy { return; }
        if not incident.strip() {
            error = "Enter an incident name before uploading.";
            return;
        }
        if not source.strip() {
            error = "Enter the supplied source or reference before uploading.";
            return;
        }
        if not preview {
            error = "Choose an image to preview before uploading.";
            return;
        }
        busy = True;
        try {
            uploaded = await upload_image(incident, selected_name, source, preview);
            uploads = [uploaded] + uploads;
            notice = "Image uploaded and hashed on the server. SHA-256: " + uploaded.sha256;
            await onRefresh();
        } except Exception as e {
            error = "Upload failed: " + str(e);
        }
        busy = False;
    }

    async def handle_check {
        error = "";
        busy = True;
        try {
            uploads = await check_media_duplicates(incident);
            notice = "Exact duplicate check completed for this incident. Repeated checks update existing relationships only.";
            await onRefresh();
        } except Exception as e {
            error = "Duplicate check failed: " + str(e);
        }
        busy = False;
    }

    async def handle_incident_change(e: ChangeEvent) {
        incident = e.target.value;
        uploads = [];
        if incident.strip() {
            loading_records = True;
            try {
                uploads = await list_image_uploads(incident);
                error = "";
            } except Exception as e2 {
                error = "Could not load uploads for this incident: " + str(e2);
            }
            loading_records = False;
        }
    }

    q = query.strip().lower();
    media = [m for m in snapshot.media
        if (incident.strip().lower() == snapshot.incident_name.strip().lower())
        and (mediaType == "all" or m.media_type == mediaType)
        and (q == "" or q in m.description.lower() or q in m.location_name.lower())];
    visible_uploads = [item for item in uploads
        if item.incident.strip().lower() == incident.strip().lower()
        and (mediaType == "all" or mediaType == "image")
        and (q == "" or q in item.filename.lower() or q in item.source_reference.lower()
            or q in item.incident.lower())];
    if q and len(media) == 0 and len(visible_uploads) == 0 {
        notice = "No incident media matches that search.";
    }

    return <div className="flex flex-col gap-5">
        <SectionHeading title="Media evidence" subtitle="Upload a controlled image, preserve its source, and inspect exact file matches without overstating what a copy proves." />
        <section className="grid gap-4 rounded-xl border border-border bg-card p-4 shadow-sm md:grid-cols-2 md:p-6">
            <div className="flex flex-col gap-4">
                <div>
                    <h2 className="text-lg font-semibold tracking-tight">Upload an image</h2>
                    <p className="text-sm text-muted-foreground">Files up to 6 MB. The server calculates SHA-256 from the image bytes.</p>
                </div>
                <label className="flex flex-col gap-1.5 text-sm font-medium">Incident scope
                    <input value={incident} onChange={handle_incident_change} placeholder="Incident name" className="h-10 rounded-md border border-input bg-background px-3 font-normal focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                </label>
                <label className="flex flex-col gap-1.5 text-sm font-medium">Supplied source or reference
                    <input value={source} onChange={lambda (e: ChangeEvent) { source = e.target.value; }} placeholder="Reporter, URL, or reference" className="h-10 rounded-md border border-input bg-background px-3 font-normal focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                </label>
                <label className="flex flex-col gap-1.5 text-sm font-medium">Image file
                    <input type="file" accept="image/png,image/jpeg,image/gif,image/webp" onChange={handle_file} className="block w-full rounded-md border border-input bg-background p-2 text-sm file:mr-3 file:rounded-md file:border-0 file:bg-muted file:px-3 file:py-1.5 file:font-medium" />
                </label>
                {selected_name and <p className="text-xs text-muted-foreground">{"Selected: " + selected_name}</p>}
                <Button onClick={handle_upload} disabled={busy}>{"Upload image" if not busy else "Uploading…"}</Button>
            </div>
            <div className="flex min-h-56 items-center justify-center overflow-hidden rounded-lg border border-dashed border-border bg-muted/30 p-3">
                {preview and <img src={preview} alt="Selected image preview" className="max-h-80 max-w-full rounded-md object-contain" />}
                {not preview and <p className="text-sm text-muted-foreground">Select an image to see its preview before upload.</p>}
            </div>
        </section>
        {error and <p role="alert" className="rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm text-destructive">{error}</p>}
        {notice and <p role="status" className="break-all rounded-md border border-primary/30 bg-primary/5 p-3 text-sm text-foreground">{notice}</p>}
        <section className="flex flex-col gap-4 rounded-xl border border-border bg-card p-4 shadow-sm md:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
                <div><h2 className="text-lg font-semibold tracking-tight">Uploaded records</h2>
                    <p className="text-sm text-muted-foreground">Saved records remain available after refresh. Exact matches are compared only within the incident above.</p></div>
                <Button variant="outline" onClick={handle_check} disabled={busy or not incident.strip()}>{"Check exact duplicates"}</Button>
            </div>
            {loading_records and <p className="rounded-lg border bg-muted/30 p-6 text-sm text-muted-foreground">Loading saved uploads…</p>}
            {not loading_records and len(visible_uploads) == 0 and len(media) == 0 and <div className="rounded-lg border border-dashed bg-muted/20 p-8 text-center"><h3 className="font-medium">No matching incident media</h3><p className="mt-1 text-sm text-muted-foreground">Try another search, or upload an image with its source reference.</p></div>}
            {len(media) > 0 and <EvidencePanel media={media} />}
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {for item in visible_uploads {
                    <article key={item.id} className="flex min-w-0 flex-col gap-2 rounded-lg border bg-background p-3 shadow-sm">
                        <img src={item.data_url} alt={"Uploaded preview: " + item.filename} className="h-44 w-full rounded-md bg-muted object-contain" />
                        <h3 className="truncate text-sm font-semibold">{item.filename}</h3>
                        <p className="break-all text-xs text-muted-foreground">{"Source: " + item.source_reference}</p>
                        <p className="text-xs text-muted-foreground">{"Incident: " + item.incident}</p>
                        <p className="text-xs text-muted-foreground">{"Uploaded: " + item.uploaded_at}</p>
                        <p className="break-all font-mono text-xs text-muted-foreground">{"SHA-256: " + item.sha256}</p>
                        {len(item.duplicate_ids) > 0 and <DuplicateDetails item={item} uploads={uploads} />}
                    </article>
                }}
            </div>
        </section>
        <div className="flex flex-wrap items-end gap-3">
            <label className="flex min-w-0 flex-1 flex-col gap-2 text-sm"><span className="font-medium">Search existing incident media</span>
                <input type="search" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }} placeholder="Search descriptions or places" className="h-10 rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            </label>
            <label className="flex flex-col gap-2 text-sm"><span className="font-medium">Media type</span>
                <select value={mediaType} onChange={lambda (e: ChangeEvent) { mediaType = e.target.value; }} className="h-10 rounded-md border border-input bg-card px-3 text-foreground focus-visible:ring-2 focus-visible:ring-ring"><option value="all">All media</option><option value="image">Photos</option><option value="video">Videos</option></select>
            </label>
        </div>
    </div>;
}
