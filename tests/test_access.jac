"""The write lock: off without TRACE_LIVE_PASSPHRASE, enforced with it."""
import os;
import from services.access { write_gate, editing_access }
import from services.trace { reset_demo, get_dashboard }
import from features.organizations.services { publish_report }
import from features.organizations.pfif { import_pfif }
import from features.media.media_upload {
    upload_image, edit_media, delete_media, add_media_comment, add_media_assertion
}

glob KEY: str = "TRACE_LIVE_PASSPHRASE";
glob PNG: str = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";

def set_key(value: str) -> str {
    before = os.environ.get(KEY, "");
    if value { os.environ[KEY] = value; } else { os.environ.pop(KEY, None); }
    return before;
}

def refused(call: any) -> bool {
    try {
        call();
    } except ValueError as e {
        return "locked" in str(e);
    }
    return False;
}

test "nothing is locked when the server sets no passphrase" {
    before = set_key("");
    try {
        assert write_gate("") == "" and write_gate("anything") == "";
        access = editing_access();
        assert not access.locked and access.allowed;
        # Blank settings count as unset instead of locking the site.
        set_key("  \n");
        assert write_gate("") == "" and not editing_access().locked;
    } finally {
        set_key(before);
    }
}

test "a set passphrase must match exactly" {
    before = set_key("open-sesame\n");
    try {
        assert write_gate("open-sesame") == "" and write_gate(" open-sesame ") == "";
        for wrong in ["", " ", "open-sesam", "open-sesame!", "OPEN-SESAME", "open-sesame\x00", "\ud800"] {
            assert "locked" in write_gate(wrong);
        }
        locked = editing_access("nope");
        assert locked.locked and not locked.allowed;
        assert editing_access("open-sesame").allowed;
    } finally {
        set_key(before);
    }
}

test "locked writes change nothing and say why" {
    reset_demo();
    snap = get_dashboard();
    before = set_key("open-sesame");
    try {
        name = snap.incident_name;
        published = publish_report(snap.incident_id, snap.organizations[0].id, snap.people[0].id,
            "FOUND_SAFE", "s", "", "LOCK-TEST-001", "o");
        assert "locked" in published.error and published.claim_id == "";
        assert "locked" in import_pfif(snap.incident_id, snap.organizations[0].id, "<pfif/>").error;
        assert refused(lambda { upload_image(name, "a.png", "ref", PNG); });
        assert refused(lambda { edit_media("x", name, "t", "s", "d"); });
        assert refused(lambda { delete_media("x", name); });
        assert refused(lambda { add_media_comment("x", name, "hello", "me"); });
        assert refused(lambda { add_media_assertion("x", name, "LOCATION_OR_SOURCE", "v", "s", "p"); });
        after = get_dashboard();
        assert len(after.people[0].claims) == len(snap.people[0].claims);
        assert len(after.media) == len(snap.media);

        opened = publish_report(snap.incident_id, snap.organizations[0].id, snap.people[0].id,
            "FOUND_SAFE", "s", "", "LOCK-TEST-001", "o", "open-sesame");
        assert opened.error == "" and opened.claim_id != "";
    } finally {
        set_key(before);
        reset_demo();
    }
}
