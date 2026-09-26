"""Controlled image uploads with incident-scoped exact SHA-256 matching."""
import base64;
import hashlib;
import from datetime { datetime, timezone }

obj UploadRecord {
    has id: str, incident: str, filename: str, source_reference: str,
        uploaded_at: str, sha256: str, data_url: str, duplicate_ids: list[str] = [];
}

node IncidentImageUpload {
    has incident: str,
        filename: str = "",
        source_reference: str = "",
        uploaded_at: str = "",
        sha256: str = "",
        data_url: str = "",
        duplicate_ids: list[str] = [];
}

# Validate and persist one small image; contents stay available for previews after refresh.
def:pub upload_image(incident: str, filename: str, source_reference: str, data_url: str) -> UploadRecord {
    if not incident.strip() {
        raise ValueError("Enter the incident name to keep duplicate checks scoped correctly.");
    }
    if not source_reference.strip() {
        raise ValueError("Enter the supplied source or reference before uploading.");
    }
    if len(data_url) > 8_000_000 {
        raise ValueError("This image is too large. Choose an image under 6 MB.");
    }
    if not data_url.startswith("data:image/") or ";base64," not in data_url {
        raise ValueError("Choose a valid PNG, JPEG, GIF, or WebP image.");
    }
    parts = data_url.split(",", 1);
    if len(parts) != 2 {
        raise ValueError("The image could not be read. Choose it again and retry.");
    }
    try {
        content = base64.b64decode(parts[1], validate=True);
    } except Exception {
        raise ValueError("The image data is invalid. Choose the image again and retry.");
    }
    if len(content) == 0 or len(content) > 6_000_000 {
        raise ValueError("Choose a non-empty image under 6 MB.");
    }
    mime = parts[0].lower();
    supported = False;
    if mime.startswith("data:image/png;") {
        supported = content.startswith(b"\x89PNG\r\n\x1a\n");
    } elif mime.startswith("data:image/jpeg;") {
        supported = content.startswith(b"\\xff\\xd8\\xff");
    } elif mime.startswith("data:image/gif;") {
        supported = content.startswith(b"GIF87a") or content.startswith(b"GIF89a");
    } elif mime.startswith("data:image/webp;") {
        supported = len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP";
    }
    if not supported {
        raise ValueError("The file bytes do not match a valid PNG, JPEG, GIF, or WebP image. Re-export the image and try again.");
    }
    digest = hashlib.sha256(content).hexdigest();
    matches = [m for m in [root -->][?:IncidentImageUpload]
        if m.incident.strip().lower() == incident.strip().lower() and m.sha256 == digest];
    new_record = root ++> IncidentImageUpload(
        incident=incident.strip(), filename=filename[:240],
        source_reference=source_reference.strip()[:1000],
        uploaded_at=datetime.now(timezone.utc).isoformat(), sha256=digest,
        data_url=data_url, duplicate_ids=[jid(m) for m in matches]
    );
    # Matching is SHA-256 only; incident names are normalized solely for scoping.
    for old in matches {
        if jid(new_record) not in old.duplicate_ids {
            old.duplicate_ids = old.duplicate_ids + [jid(new_record)];
        }
    }
    return _record_view(new_record);
}

def:pub list_image_uploads(incident: str) -> list[UploadRecord] {
    records: list[UploadRecord] = [];
    for item in [root -->][?:IncidentImageUpload] {
        if item.incident.strip().lower() == incident.strip().lower() {
            records.append(_record_view(item));
        }
    }
    records.sort(key=lambda (r: UploadRecord) -> str { return r.uploaded_at; });
    return records;
}

# Recompute duplicate links idempotently; these are fields, not appended result nodes.
def:pub check_media_duplicates(incident: str) -> list[UploadRecord] {
    items = [m for m in [root -->][?:IncidentImageUpload]
        if m.incident.strip().lower() == incident.strip().lower()];
    for item in items {
        item.duplicate_ids = [jid(other) for other in items
            if jid(other) != jid(item) and other.sha256 == item.sha256];
    }
    return [_record_view(item) for item in items];
}

def _record_view(item: IncidentImageUpload) -> UploadRecord {
    return UploadRecord(id=jid(item), incident=item.incident, filename=item.filename,
        source_reference=item.source_reference, uploaded_at=item.uploaded_at,
        sha256=item.sha256, data_url=item.data_url, duplicate_ids=item.duplicate_ids);
}
