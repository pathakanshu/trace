"""Incident-scoped operations on canonical Media nodes."""
import base64;
import hashlib;
import from datetime { datetime, timezone }
import from graph.nodes { Incident, Media, MediaMetadata, MediaComment, MediaAssertion, VerificationSignal }
import from graph.edges { Contains, HasSignal, SupportedBy, ExactCopyOf }

obj MediaCommentView {
    has id: str, body: str, author: str, created_at: str;
}

obj MediaAssertionView {
    has id: str, assertion_type: str, value: str, source: str,
        asserted_at: str, provenance: str, status: str;
}

obj UploadRecord {
    has id: str, incident: str, filename: str, display_name: str,
        source_reference: str, uploaded_at: str, sha256: str, data_url: str,
        description: str, duplicate_ids: list[str] = [],
        comments: list[MediaCommentView] = [], assertions: list[MediaAssertionView] = [];
}

# Validate the decoded bytes, then create a canonical Media node under the existing incident.
def:pub upload_image(incident: str, filename: str, source_reference: str, data_url: str) -> UploadRecord {
    if not incident.strip() { raise ValueError("Enter the incident name to scope this media item."); }
    if not source_reference.strip() { raise ValueError("Enter the supplied source or reference."); }
    if len(data_url) > 8_000_000 { raise ValueError("Choose an image under 6 MB."); }
    if not data_url.startswith("data:image/") or ";base64," not in data_url {
        raise ValueError("Choose a PNG, JPEG, GIF, or WebP image.");
    }
    parts = data_url.split(",", 1);
    if len(parts) != 2 { raise ValueError("The image could not be read. Choose it again."); }
    try { content = base64.b64decode(parts[1], validate=True); }
    except Exception { raise ValueError("The image data is invalid. Choose it again."); }
    if len(content) == 0 or len(content) > 6_000_000 {
        raise ValueError("Choose a non-empty image under 6 MB.");
    }
    mime = parts[0].lower();
    valid = False;
    if mime.startswith("data:image/png;") { valid = content.startswith(b"\x89PNG\r\n\x1a\n"); }
    elif mime.startswith("data:image/jpeg;") { valid = content.startswith(b"\xff\xd8\xff"); }
    elif mime.startswith("data:image/gif;") { valid = content.startswith(b"GIF87a") or content.startswith(b"GIF89a"); }
    elif mime.startswith("data:image/webp;") { valid = len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP"; }
    if not valid { raise ValueError("File bytes do not match a supported PNG, JPEG, GIF, or WebP image."); }

    incident_node = _find_incident(incident);
    if incident_node is None { raise ValueError("That incident does not exist. Choose an incident already in Trace."); }
    digest = hashlib.sha256(content).hexdigest();
    matches: list[str] = [];
    for existing in [incident_node ->:Contains:->] {
        meta = _metadata(existing);
        if meta and meta.sha256 == digest {
            if meta.source_reference == source_reference.strip()[:1000] and meta.filename == filename[:240] {
                return _record_view(incident_node, existing);
            }
            matches.append(jid(existing));
        }
    }
    uploaded_at = datetime.now(timezone.utc).isoformat();
    uploaded = Media(media_type="image", url="", captured_at="",
        description=filename[:240], content_hash=digest, origin="upload", uploaded_at=uploaded_at);
    incident_node +>:Contains():+> uploaded;
    _ = uploaded ++> MediaMetadata(media_id=jid(uploaded), filename=filename[:240],
        display_name=filename[:240], source_reference=source_reference.strip()[:1000],
        sha256=digest, data_url=data_url, duplicate_ids=matches);
    for existing in [incident_node ->:Contains:->] {
        if jid(existing) in matches {
            uploaded +>:ExactCopyOf(detected_by="SHA-256 upload", detected_at=uploaded_at):+> existing;
            old_meta = _metadata(existing);
            if old_meta and jid(uploaded) not in old_meta.duplicate_ids {
                old_meta.duplicate_ids = old_meta.duplicate_ids + [jid(uploaded)];
            }
        }
    }
    return _record_view(incident_node, uploaded);
}

def:pub list_image_uploads(incident: str) -> list[UploadRecord] {
    return list_incident_media(incident);
}

def:pub list_incident_media(incident: str) -> list[UploadRecord] {
    incident_node = _find_incident(incident);
    result: list[UploadRecord] = [];
    if incident_node is None { return result; }
    for item in [incident_node ->:Contains:->] { result.append(_record_view(incident_node, item)); }
    return result;
}

# The corpus incident is not reachable by name from root, so its snapshot
# passes the incident and media nodes it already scanned.
def media_record_views(incident: Incident, items: list[Media]) -> list[UploadRecord] {
    return [_record_view(incident, item) for item in items];
}

# Recalculate exact SHA relationships, only within one incident and without result nodes.
def:pub check_media_duplicates(incident: str) -> list[UploadRecord] {
    incident_node = _find_incident(incident);
    if incident_node is None { return []; }
    items = [item for item in [incident_node ->:Contains:->] if _metadata(item)];
    for item in items {
        meta = _metadata(item);
        related: list[str] = [];
        if meta {
            for other in items {
                other_meta = _metadata(other);
                if other_meta and jid(item) != jid(other) and meta.sha256 == other_meta.sha256 {
                    related.append(jid(other));
                }
            }
            meta.duplicate_ids = related;
        }
    }
    return [_record_view(incident_node, item) for item in items];
}

def:pub edit_media(media_id: str, incident: str, display_name: str, source_reference: str, description: str) -> UploadRecord | None {
    incident_node = _find_incident(incident);
    if incident_node is None { return None; }
    for item in [incident_node ->:Contains:->] {
        if jid(item) == media_id {
            item.description = description.strip()[:2000];
            meta = _metadata(item);
            if meta {
                meta.display_name = display_name.strip()[:240];
                meta.source_reference = source_reference.strip()[:1000];
                return _record_view(incident_node, item);
            }
        }
    }
    return None;
}

def:pub delete_media(media_id: str, incident: str) -> bool {
    incident_node = _find_incident(incident);
    if incident_node is None { return False; }
    for item in [incident_node ->:Contains:->] {
        if jid(item) == media_id {
            # Seeded, claim-linked, and shared records remain evidence for other views.
            if not _metadata(item) or [item <-:SupportedBy:<-] or len([item <-:Contains:<-]) != 1 {
                raise ValueError("Only an unreferenced upload owned by this incident can be deleted.");
            }
            removed = jid(item);
            for remaining in [incident_node ->:Contains:->] {
                meta = _metadata(remaining);
                if meta and removed in meta.duplicate_ids {
                    meta.duplicate_ids = [key for key in meta.duplicate_ids if key != removed];
                }
            }
            for child in [item -->] {
                if isinstance(child, (MediaMetadata, MediaComment, MediaAssertion, VerificationSignal)) {
                    if all([jid(parent) == removed for parent in [child <--]]) { del child; }
                }
            }
            del item;
            return True;
        }
    }
    return False;
}

def:pub add_media_comment(media_id: str, incident: str, body: str, author: str) -> MediaCommentView | None {
    incident_node = _find_incident(incident);
    if incident_node is None or not body.strip() { return None; }
    for item in [incident_node ->:Contains:->] {
        if jid(item) == media_id {
            comment = item ++> MediaComment(body=body.strip()[:4000], author=author.strip()[:160],
                created_at=datetime.now(timezone.utc).isoformat());
            return MediaCommentView(id=jid(comment), body=comment.body, author=comment.author, created_at=comment.created_at);
        }
    }
    return None;
}

def:pub add_media_assertion(media_id: str, incident: str, assertion_type: str, value: str, source: str, provenance: str) -> MediaAssertionView | None {
    incident_node = _find_incident(incident);
    if incident_node is None or not value.strip() or not source.strip() { return None; }
    for item in [incident_node ->:Contains:->] {
        if jid(item) == media_id {
            assertion = item ++> MediaAssertion(assertion_type=assertion_type[:80], value=value.strip()[:1000],
                source=source.strip()[:500], asserted_at=datetime.now(timezone.utc).isoformat(),
                provenance=provenance.strip()[:500], status="reported");
            return MediaAssertionView(id=jid(assertion), assertion_type=assertion.assertion_type,
                value=assertion.value, source=assertion.source, asserted_at=assertion.asserted_at,
                provenance=assertion.provenance, status=assertion.status);
        }
    }
    return None;
}

# Internal helpers

def _find_incident(name: str) -> Incident | None {
    for item in [root -->][?:Incident] {
        if item.name.strip().lower() == name.strip().lower() { return item; }
    }
    return None;
}

def _metadata(item: Media) -> MediaMetadata | None {
    for child in [item -->][?:MediaMetadata] { return child; }
    return None;
}

def _record_view(incident: Incident, item: Media) -> UploadRecord {
    meta = _metadata(item);
    comments: list[MediaCommentView] = [];
    assertions: list[MediaAssertionView] = [];
    for child in [item -->][?:MediaComment] {
        comments.append(MediaCommentView(id=jid(child), body=child.body, author=child.author, created_at=child.created_at));
    }
    for child in [item -->][?:MediaAssertion] {
        assertions.append(MediaAssertionView(id=jid(child), assertion_type=child.assertion_type,
            value=child.value, source=child.source, asserted_at=child.asserted_at,
            provenance=child.provenance, status=child.status));
    }
    return UploadRecord(id=jid(item), incident=incident.name,
        filename=meta.filename if meta else item.description,
        display_name=meta.display_name if meta else item.description,
        source_reference=meta.source_reference if meta else "",
        uploaded_at=item.uploaded_at,
        sha256=meta.sha256 if meta else "",
        data_url=meta.data_url if meta else item.url,
        description=item.description, duplicate_ids=meta.duplicate_ids if meta else [],
        comments=comments, assertions=assertions);
}
