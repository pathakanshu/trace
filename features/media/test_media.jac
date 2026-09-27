import from features.media.media_upload { upload_image, list_image_uploads, check_media_duplicates }
import from graph.nodes { Incident }
import base64;

# Tiny PNG with valid signature; rest is enough for current PNG byte validation.
glob PNG_SAMPLE: any = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/Z1sAAAAASUVORK5CYII=");
glob PNG_OTHER: any = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC");

def _data_url(data: any) -> str {
    return "data:image/png;base64," + base64.b64encode(data).decode();
}

test "duplicate test" {
    root ++> Incident(name="Upload Test Incident One");
    root ++> Incident(name="Upload Test Incident Two");
    first = upload_image("Upload Test Incident One", "rain.png", "field notebook 1", _data_url(PNG_SAMPLE));
    second = upload_image("Upload Test Incident One", "renamed.png", "volunteer source 2", _data_url(PNG_SAMPLE));
    different = upload_image("Upload Test Incident One", "other.png", "source 3", _data_url(PNG_OTHER));
    elsewhere = upload_image("Upload Test Incident Two", "same-bytes.png", "source 4", _data_url(PNG_SAMPLE));

    assert first.sha256 == second.sha256;
    assert first.id in second.duplicate_ids;
    first_fresh = [r for r in list_image_uploads("Upload Test Incident One") if r.id == first.id][0];
    assert second.id in first_fresh.duplicate_ids;
    assert first.sha256 != different.sha256;
    assert len(different.duplicate_ids) == 0;
    assert len(elsewhere.duplicate_ids) == 0;

    checked_once = check_media_duplicates("Upload Test Incident One");
    checked_twice = check_media_duplicates("Upload Test Incident One");
    assert len(checked_once) == len(checked_twice);
    for row in checked_once {
        for again in checked_twice {
            if row.id == again.id {
                assert row.duplicate_ids == again.duplicate_ids;
            }
        }
    }
}

test "upload metadata persists through graph list reads" {
    root ++> Incident(name="Upload Persistence Test");
    saved = upload_image("Upload Persistence Test", "bridge.png", "https://source.invalid/report/7", _data_url(PNG_SAMPLE));
    listed = list_image_uploads("Upload Persistence Test");
    found = False;
    for row in listed {
        if row.id == saved.id {
            found = row.source_reference == "https://source.invalid/report/7"
                and row.uploaded_at == saved.uploaded_at
                and row.sha256 == saved.sha256
                and row.data_url == saved.data_url;
        }
    }
    assert found;
}

test "invalid upload data produces actionable error" {
    did_raise = False;
    try {
        upload_image("Upload Invalid Test", "not-image.png", "source reference", "data:image/png;base64,SGVsbG8=");
    } except ValueError as err {
        did_raise = "bytes" in str(err) or "image" in str(err);
    }
    assert did_raise;
}
