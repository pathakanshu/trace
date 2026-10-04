"""Offline checks use isolated Jac test graphs, never seeded vote counts."""
import from features.media.community { community_media, set_media_vote }
import from graph.nodes { Media }
import from graph.media_votes { MediaVote }
import from services.trace { reset_demo, get_dashboard }

glob BROWSER_A: str = "14648fc0-8254-4a86-8f91-59f55ca93b07";
glob BROWSER_B: str = "2434ef5f-ea8a-4122-afdc-b32df9010451";

test "library registers real files once without invented votes or incident links" {
    rows = community_media();
    again = community_media();
    assert len(rows) == 29 and len({r.graph_id for r in rows}) == 29;
    assert [r.graph_id for r in rows] == [r.graph_id for r in again];
    assert len([r for r in rows if r.media_type == "video"]) == 9;
    assert len([r for r in rows if r.media_type == "image"]) == 20;
    assert all([r.vote_count == 0 and not r.voted and r.available and r.poster_url for r in rows]);
    assert all([r.url.startswith("/assets/community-media/") and r.sha256 for r in rows]);
}

test "votes are idempotent and reversible per browser and per file" {
    items = community_media();
    key = items[0].id;
    assert set_media_vote(key, BROWSER_A, True).vote_count == 1;
    assert set_media_vote(key, BROWSER_A, True).vote_count == 1;
    assert set_media_vote(key, BROWSER_B, True).vote_count == 2;
    assert set_media_vote(key, BROWSER_A, False).vote_count == 1;
    assert set_media_vote(key, BROWSER_A, False).vote_count == 1;
    a = [r for r in community_media(BROWSER_A) if r.id == key][0];
    b = [r for r in community_media(BROWSER_B) if r.id == key][0];
    assert not a.voted and b.voted;
    assert [r for r in community_media() if r.id == items[1].id][0].vote_count == 0;
    assert set_media_vote(key, BROWSER_B, False).vote_count == 0;
}

test "invalid browser or asset identifiers cannot add votes" {
    key = community_media()[0].id;
    for invalid in ["", "not-a-key", "../path", "00000000-0000-0000-0000-000000000000"] {
        rejected = False;
        try { set_media_vote(key, invalid, True); }
        except ValueError { rejected = True; }
        assert rejected;
    }
    rejected = False;
    try { set_media_vote("unknown-asset", BROWSER_A, True); }
    except ValueError { rejected = True; }
    assert rejected;
    assert all([r.vote_count == 0 for r in community_media()]);
}

test "vote persists in graph with a hashed browser key and remains anonymous to readers" {
    key = community_media()[0].id;
    set_media_vote(key, BROWSER_A, True);
    media = [m for m in [root -->[?:Media, origin == "community-library"]] if m.external_id == key][0];
    votes = [media -->[?:MediaVote]];
    assert len(votes) == 1 and votes[0].active;
    assert len(votes[0].voter_hash) == 64 and votes[0].voter_hash != BROWSER_A;
    assert votes[0].created_at and votes[0].updated_at;
    row = [r for r in community_media() if r.id == key][0];
    assert row.vote_count == 1 and not row.voted;
}

test "demo reset preserves shared library votes without altering demo fixtures" {
    reset_demo();
    before = get_dashboard();
    item = community_media()[0];
    set_media_vote(item.id, BROWSER_A, True);
    after = get_dashboard();
    assert [p.id for p in before.people] == [p.id for p in after.people];
    assert len(after.media) == len(before.media) and len(after.alerts) == 0;
    reset_demo();
    row = [r for r in community_media(BROWSER_A) if r.id == item.id][0];
    assert row.graph_id == item.graph_id and row.vote_count == 1 and row.voted;
    assert len(get_dashboard().media) == len(before.media);
}
