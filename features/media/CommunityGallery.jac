"""Photos, playable clips and usefulness votes in the shared media library."""
import from .MediaPreview { MediaPreview }
import from ...components.ui.button { Button }
import from ...components.shared.Display { SectionHeading }
sv import from .community { CommunityMediaView, community_media, set_media_vote }

def:pub CommunityGallery() -> JsxElement {
    has rows: list[CommunityMediaView] = [], browserKey: str = "", loading: bool = True,
        busyId: str = "", error: str = "", notice: str = "", storageNote: str = "",
        query: str = "", kind: str = "all", sortBy: str = "votes", shown: int = 12,
        requestRef: Ref[int] = Ref(0);

    async def refresh(key: str) -> None {
        requestRef.current += 1;
        request = requestRef.current;
        loading = True; error = "";
        try {
            loaded = await community_media(key);
            if request == requestRef.current { rows = loaded; }
        } except Exception {
            if request == requestRef.current { error = "The shared media library could not load. Try Refresh media."; }
        } finally {
            if request == requestRef.current { loading = False; }
        }
    }
    can with entry {
        key = "";
        try {
            key = localStorage.getItem("trace-media-voter-v1") or "";
            if not key or len(key) != 36 {
                key = str((window as any).crypto.randomUUID());
                localStorage.setItem("trace-media-voter-v1", key);
            }
        } except Exception {
            key = "";
            storageNote = "Browser storage is unavailable. You can browse media; enable storage to vote.";
        }
        browserKey = key;
        refresh(key);
    }
    can with exit { requestRef.current += 1; }
    can with [kind, query, sortBy] entry { shown = 12; }

    async def vote(item: CommunityMediaView) -> None {
        if busyId or not browserKey { return; }
        busyId = item.id; error = ""; notice = "";
        try {
            updated = await set_media_vote(item.id, browserKey, not item.voted);
            rows = [updated if row.id == updated.id else row for row in rows];
            notice = ("Marked " + item.title + " useful.") if updated.voted else ("Removed your vote for " + item.title + ".");
        } except Exception { error = "Your vote could not be saved. Try again; repeated requests do not add extra votes."; }
        finally { busyId = ""; }
    }

    q = query.strip().lower();
    filtered = [item for item in rows if (kind == "all" or item.media_type == kind)
        and (not q or q in item.title.lower() or q in item.original_filename.lower())];
    # Numeric keys avoid JavaScript's string comparison of tuple/array keys.
    # The second stable sort preserves newest-added ordering for equal counts.
    ordered = sorted(filtered, key=lambda (item: CommunityMediaView) { return -item.order; });
    if sortBy == "votes" {
        ordered = sorted(ordered, key=lambda (item: CommunityMediaView) { return -item.vote_count; });
    }
    visible = ordered[:shown];
    images = len([item for item in rows if item.media_type == "image"]);
    videos = len(rows) - images;

    return <section aria-label="Shared media library" className="flex min-w-0 flex-col gap-4">
        <SectionHeading title="Community media" subtitle="Explore supplied photos and clips. Mark useful material to help reviewers decide what to inspect next." />
        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            <span className="rounded-full border border-border px-2 py-1">{"Shared across incidents"}</span>
            <span>{str(images) + " photos · " + str(videos) + " videos"}</span>
        </div>
        <p className="rounded-md border border-status-warning/30 bg-status-warning-soft p-3 text-sm text-status-warning">{"User-supplied media. Source, date and location are unverified. Votes indicate usefulness for review; they do not verify a file or link it to the selected incident."}</p>
        <div className="flex flex-wrap items-end gap-3">
            <label className="flex min-w-0 w-full flex-col gap-1 text-sm sm:w-auto sm:flex-1">{"Search supplied media"}<input type="search" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }} placeholder="Photo, clip or filename" className="h-10 min-w-0 rounded-md border border-input bg-background px-3" /></label>
            <label className="flex flex-col gap-1 text-sm">{"Media type"}<select aria-label="Media type" value={kind} onChange={lambda (e: ChangeEvent) { kind = e.target.value; }} className="h-10 rounded-md border border-input bg-card px-3"><option value="all">All media</option><option value="image">Photos</option><option value="video">Videos</option></select></label>
            <label className="flex flex-col gap-1 text-sm">{"Sort media"}<select aria-label="Sort media" value={sortBy} onChange={lambda (e: ChangeEvent) { sortBy = e.target.value; }} className="h-10 rounded-md border border-input bg-card px-3"><option value="votes">Most useful</option><option value="newest">Newest added</option></select></label>
            <Button variant="outline" disabled={loading or bool(busyId)} onClick={lambda { refresh(browserKey); }}>Refresh media</Button>
        </div>
        {storageNote and <p className="text-sm text-muted-foreground">{storageNote}</p>}
        <p className="text-xs text-muted-foreground">{"One removable vote per file in this browser. Counts are shared and saved on the server; this is not signed-in identity voting."}</p>
        {loading and <p role="status" className="text-sm text-muted-foreground">Loading shared media…</p>}
        {error and <p role="alert" className="text-sm text-destructive">{error}</p>}
        {notice and <p role="status" className="text-sm text-primary">{notice}</p>}
        {not loading and not error and not filtered and <p className="rounded-md border border-border p-6 text-sm text-muted-foreground">No supplied media matches this search.</p>}
        <div className="grid min-w-0 items-start gap-4 md:grid-cols-2 xl:grid-cols-3">
            {for item in visible {
                <article key={item.id} data-media-id={item.id} className="flex min-w-0 flex-col overflow-hidden rounded-lg border border-border bg-card">
                    <MediaPreview item={item} />
                    <div className="flex min-w-0 flex-col gap-3 p-4">
                        <div className="flex items-center justify-between gap-2"><h3 className="font-display text-xl">{item.title}</h3><span className="rounded-full border border-border px-2 py-0.5 text-xs text-muted-foreground">{("Video · " + str(round(item.duration_seconds)) + "s") if item.media_type == "video" else "Photo"}</span></div>
                        <button type="button" aria-pressed={item.voted} disabled={not browserKey or bool(busyId) or loading} onClick={lambda { vote(item); }} className={"flex min-h-10 items-center justify-between gap-3 rounded-md border px-3 py-2 text-sm font-medium disabled:opacity-50 " + ("border-primary bg-primary/10 text-primary" if item.voted else "border-border hover:bg-accent")}><span>{"Saving…" if busyId == item.id else ("Useful ✓ · undo" if item.voted else "↑ Useful for review")}</span><span className="tabular-nums">{str(item.vote_count)}</span></button>
                        <details className="min-w-0 text-xs text-muted-foreground"><summary className="cursor-pointer">File and source details</summary><div className="mt-2 flex flex-col gap-2 break-words"><p>{item.original_filename}</p><p>{item.source_reference}</p><p>{item.conversion}</p><p>{str(item.width) + " × " + str(item.height) + " · " + str(round(item.bytes / 1000000, 1)) + " MB"}</p><p className="break-all">{"SHA-256: " + item.sha256}</p></div></details>
                    </div>
                </article>
            }}
        </div>
        {len(ordered) > 0 and <p className="text-xs text-muted-foreground">{"Showing " + str(len(visible)) + " of " + str(len(ordered)) + " matching files."}</p>}
        {shown < len(ordered) and <Button variant="outline" onClick={lambda { shown += 12; }}>Show more media</Button>}
    </section>;
}
