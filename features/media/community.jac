"""Persistent shared review library and idempotent usefulness votes. No models."""
import json;
import hashlib;
import from threading { RLock }
import uuid;
import from pathlib { Path }
import from datetime { datetime, timezone }
import from graph.nodes { Media, MediaMetadata }
import from graph.media_votes { MediaVote }

glob LIBRARY_LOCK: RLock = RLock();
glob PROJECT: Path = Path(str(__file__)).resolve().parents[2];
glob MANIFEST: Path = Path(str(__file__)).resolve().parent / "community-manifest.json";

obj CommunityMediaView {
    has id: str, graph_id: str, title: str, media_type: str, url: str,
        poster_url: str, original_filename: str, source_reference: str,
        added_at: str, conversion: str, sha256: str, width: int, height: int,
        duration_seconds: float, bytes: int, order: int,
        vote_count: int = 0, voted: bool = False, available: bool = True;
}

def _voter_hash(browser_key: str) -> str {
    if not browser_key { return ""; }
    if len(browser_key) != 36 { raise ValueError("Voting needs a valid browser identifier. Clear this site's stored voter key and refresh."); }
    try { parsed = uuid.UUID(browser_key); }
    except ValueError { raise ValueError("The browser voting identifier is invalid."); }
    if parsed.version != 4 or str(parsed) != browser_key.lower() {
        raise ValueError("The browser voting identifier is invalid.");
    }
    return hashlib.sha256(("trace-community-vote-v1:" + str(parsed)).encode()).hexdigest();
}

def _manifest() -> list[dict] {
    with MANIFEST.open(encoding="utf-8") as handle { content = json.load(handle); }
    return content["items"];
}

def _registered(items: list[dict]) -> dict[str, Media] {
    found: dict[str, Media] = {};
    for media in [root -->[?:Media, origin == "community-library"]] {
        found[media.external_id] = media;
    }
    for item in items {
        key = str(item["asset_id"]);
        if key not in found {
            # One canonical Media per original SHA-256; repeated reads reuse it.
            media = Media(media_type=str(item["media_type"]), url=str(item["url"]),
                description=str(item["title"]), origin="community-library",
                external_id=key, content_hash=str(item["sha256"]),
                uploaded_by="User supplied", uploaded_at=str(item["added_at"]));
            root ++> media;
            media ++> MediaMetadata(media_id=jid(media), filename=str(item["original_filename"]),
                display_name=str(item["title"]), source_reference=str(item["source_reference"]),
                sha256=str(item["sha256"]), data_url=str(item["url"]));
            found[key] = media;
        }
    }
    return found;
}

def _view(item: dict, media: Media, voter_hash: str) -> CommunityMediaView {
    voters: set[str] = {vote.voter_hash for vote in [media -->[?:MediaVote, active == True]]};
    # Metadata can remain available even if a deployment omitted a binary asset.
    relative = str(item["url"]).lstrip("/");
    available = (PROJECT / relative).is_file();
    return CommunityMediaView(id=str(item["asset_id"]), graph_id=jid(media), title=str(item["title"]),
        media_type=str(item["media_type"]), url=str(item["url"]), poster_url=str(item["poster_url"]),
        original_filename=str(item["original_filename"]), source_reference=str(item["source_reference"]),
        added_at=str(item["added_at"]), conversion=str(item["conversion"]), sha256=str(item["sha256"]),
        width=int(item["width"]), height=int(item["height"]), duration_seconds=float(item["duration_seconds"]),
        bytes=int(item["bytes"]), order=int(item["order"]), vote_count=len(voters),
        voted=bool(voter_hash and voter_hash in voters), available=available);
}

def:pub community_media(browser_key: str = "") -> list[CommunityMediaView] {
    digest = _voter_hash(browser_key);
    with LIBRARY_LOCK {
        items = _manifest();
        media = _registered(items);
        return [_view(item, media[str(item["asset_id"])], digest) for item in items];
    }
}

def:pub set_media_vote(asset_id: str, browser_key: str, useful: bool) -> CommunityMediaView {
    digest = _voter_hash(browser_key);
    if not digest { raise ValueError("Enable browser storage to vote."); }
    if not isinstance(useful, bool) { raise ValueError("Useful must be true or false."); }
    with LIBRARY_LOCK {
        matches = [item for item in _manifest() if item["asset_id"] == asset_id];
        if not matches { raise ValueError("This media item is not in the shared library."); }
        item = matches[0];
        media = _registered(matches)[asset_id];
        votes = [vote for vote in [media -->[?:MediaVote]] if vote.voter_hash == digest];
        now = datetime.now(timezone.utc).isoformat();
        # Set the requested state; a retried request cannot toggle or double-vote.
        if votes {
            for vote in votes { vote.active = useful; vote.updated_at = now; }
        } elif useful {
            media ++> MediaVote(voter_hash=digest, active=True, created_at=now, updated_at=now);
        }
        return _view(item, media, digest);
    }
}
