"""Bundled context checks; no importer, model, database or remote fetch."""
import json;
import hashlib;
import from services.geo { get_bhotekoshi_corridor, get_boundaries }

test "corridor retains the exact attributed five-feature input" {
    with open("features/map/bhotekoshi-corridor.geojson", "rb") as fh { raw = fh.read(); }
    assert hashlib.sha256(raw).hexdigest() == "ea8c4f2e3e49f9825e3a9b547f208a5b7db838a9b50ae1b5e4e4c1fc7189a7cf";
    corridor = get_bhotekoshi_corridor();
    assert corridor == json.loads(raw);
    assert corridor["type"] == "FeatureCollection";
    assert len(corridor["features"]) == 5;
    features: list[dict] = corridor["features"];
    points = [f for f in features if f["geometry"]["type"] == "Point"];
    assert [f["properties"]["label"] for f in points] == ["Kodari", "Tatopani", "Bahrabise", "Khadichaur"];
    river: dict = features[0];
    assert river["geometry"]["type"] == "MultiLineString";
    lines: list = river["geometry"]["coordinates"];
    assert len(lines) == 4;
    for f in features {
        assert "ODbL-1.0" in f["properties"]["source_license"];
        assert f["properties"]["source_url"].startswith("https://");
        assert f["properties"]["limitations"];
    }
}

test "corridor and boundary caches coexist regardless of first call" {
    corridor = get_bhotekoshi_corridor();
    boundaries = get_boundaries();
    assert boundaries["type"] == "Topology";
    assert "districts" in boundaries["objects"];
    assert get_bhotekoshi_corridor() == corridor;
    assert get_boundaries() == boundaries;
}
