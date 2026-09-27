"""Thumbnails only until an explicit request for a full image or video."""
sv import from .community { CommunityMediaView }

def:pub MediaPreview(item: CommunityMediaView) -> JsxElement {
    has started: bool = False, failed: bool = False;
    if not item.available {
        return <p className="flex min-h-48 items-center justify-center p-4 text-center text-sm text-muted-foreground">Media file unavailable in this deployment.</p>;
    }
    if failed {
        return <div className="flex min-h-48 flex-col items-center justify-center gap-3 p-4 text-sm text-muted-foreground"><p>The preview could not load.</p><a href={item.url} target="_blank" rel="noopener noreferrer" className="underline">Open media file</a></div>;
    }
    if item.media_type == "image" {
        return <a href={item.url} target="_blank" rel="noopener noreferrer" aria-label={"Open " + item.title + " full size"} className="block bg-muted/20"><img src={item.poster_url or item.url} alt={item.title + ": user-supplied image, location and date unverified"} loading="lazy" decoding="async" onError={lambda { failed = True; }} className="h-56 w-full object-contain" /></a>;
    }
    if not started {
        return <button type="button" aria-label={"Play " + item.title} onClick={lambda { started = True; }} className="group relative flex h-56 w-full items-center justify-center bg-muted/20">
            <img src={item.poster_url} alt={item.title + " video thumbnail"} loading="lazy" decoding="async" onError={lambda { failed = True; }} className="h-full w-full object-contain" />
            <span aria-hidden="true" className="absolute flex size-14 items-center justify-center rounded-full border border-border bg-card/95 text-2xl text-primary shadow-lg group-hover:bg-accent">▶</span>
            <span className="absolute bottom-2 rounded-full bg-card/95 px-3 py-1 text-xs text-foreground">Click to play</span>
        </button>;
    }
    # No video element or source URL is attached before the user chooses Play.
    return <video controls={True} autoPlay={True} playsInline={True} preload="none" poster={item.poster_url} aria-label={item.title} onError={lambda { failed = True; }} className="h-56 w-full bg-muted/20 object-contain"><source src={item.url} type="video/mp4" /><a href={item.url}>Open the video file</a></video>;
}
