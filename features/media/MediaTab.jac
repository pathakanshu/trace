"""Aidana's workspace. Add upload/check flows here and refresh after successful writes."""
import from .EvidencePanel { EvidencePanel }
import from ...components.shared.Display { SectionHeading }
sv import from ...services.trace { DashboardSnapshot }

def:pub MediaTab(snapshot: DashboardSnapshot, onRefresh: Callable[[], any]) -> JsxElement {
    has query: str = "", mediaType: str = "all";
    q = query.strip().lower();
    media = [m for m in snapshot.media
        if (mediaType == "all" or m.media_type == mediaType)
        and (q == "" or q in m.description.lower() or q in m.location_name.lower())];
    return <div className="flex flex-col gap-5">
        <SectionHeading title="Media" subtitle="Explore photos, videos, their sources, and the evidence attached to them." />
        <p className="rounded-md border border-status-warning/40 bg-status-warning-soft p-3 text-sm text-foreground">
            {"Seeded demonstration: these media records and analysis results are simulated. No files have been uploaded or checked."}
        </p>
        <div className="flex flex-wrap items-end gap-3">
            <label className="flex min-w-0 flex-1 flex-col gap-2 text-sm">
                <span className="font-medium">{"Search media"}</span>
                <input type="search" value={query}
                    onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                    placeholder="Search descriptions or places"
                    className="h-11 rounded-md border border-input bg-card px-3 text-base outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            </label>
            <label className="flex flex-col gap-2 text-sm">
                <span className="font-medium">{"Media type"}</span>
                <select value={mediaType} onChange={lambda (e: ChangeEvent) { mediaType = e.target.value; }}
                    className="h-11 rounded-md border border-input bg-card px-3 text-foreground focus-visible:ring-2 focus-visible:ring-ring">
                    <option value="all">{"All media"}</option>
                    <option value="image">{"Photos"}</option>
                    <option value="video">{"Videos"}</option>
                </select>
            </label>
        </div>
        <EvidencePanel media={media} />
    </div>;
}
