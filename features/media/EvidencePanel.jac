"""Aidana owns media evidence presentation and check labels."""
import from "@hugeicons/core-free-icons" { Image01Icon }
import from ...components.ui.badge { Badge }
import from ...components.shared.Display { SectionHeading, EmptyPanel, friendly_time }
import from ...lib.utils { cn }
sv import from ...services.trace { MediaView }

# Confidence as words a person trusts: how sure is this clue?
def confidence_label(confidence: str) -> str {
    if confidence == "HIGH" { return "Strong clue"; }
    if confidence == "MEDIUM" { return "Some support"; }
    if confidence == "NONE" { return "Not checked"; }
    return "Unclear";
}

def confidence_text(confidence: str) -> str {
    if confidence == "HIGH" { return "text-status-safe"; }
    if confidence == "MEDIUM" { return "text-status-warning"; }
    return "text-muted-foreground";
}

# Friendly names for each kind of media check.
def check_name(signal_type: str) -> str {
    names = {
        "EXIF_LOCATION": "Where it was taken",
        "COMMUNITY_GEOLOCATION": "Place identified by volunteers",
        "DUPLICATE_MATCH": "Posted elsewhere",
        "PROVENANCE": "Who made it",
        "SYNTHETIC_MEDIA": "AI-made or edited"
    };
    return names.get(signal_type, signal_type.replace("_", " ").lower());
}

# ---------------- Photos and videos ----------------
def:pub EvidencePanel(media: list[MediaView]) -> JsxElement {
    return <section className="flex flex-col gap-3">
        <SectionHeading title="Photos and videos" subtitle="What we could and could not check about each one. None of these checks alone proves a file is real or fake." />
        {<EmptyPanel icon={Image01Icon} title="No photos or videos yet" text="Shared photos and videos from the area will appear here." /> if len(media) == 0 else
        <div className="grid gap-3 md:grid-cols-3">
            {for m in media {
                <div key={m.id} className="flex flex-col gap-2 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3">
                    <div className="flex items-start justify-between gap-2">
                        <span className="text-sm font-medium">{m.description}</span>
                        <Badge variant="secondary">{"Photo" if m.media_type == "image" else "Video"}</Badge>
                    </div>
                    <span className="text-xs text-muted-foreground">{m.location_name + " - " + friendly_time(m.captured_at)}</span>
                    {m.earliest_known_copy and <span className="text-xs font-medium text-primary">{"Earliest copy we found (may not be the original)"}</span>}
                    {len(m.depicts) > 0 and <span className="text-xs text-muted-foreground">{"May show: " + ", ".join(m.depicts)}</span>}
                    <div className="flex flex-col divide-y divide-border rounded-md border border-border">
                        {for s in m.signals {
                            <div key={s.signal_type} className="flex flex-col gap-0.5 pt-2 pb-2 pl-2.5 pr-2.5 text-xs">
                                <div className="flex items-center justify-between gap-2">
                                    <span className="font-medium">{check_name(s.signal_type)}</span>
                                    <span className={cn("shrink-0 text-right", confidence_text(s.confidence))}>{confidence_label(s.confidence)}</span>
                                </div>
                                <span className="text-foreground">{s.value}</span>
                                <span className="text-muted-foreground">{s.explanation}</span>
                            </div>
                        }}
                    </div>
                </div>
            }}
        </div>}
    </section>;
}
