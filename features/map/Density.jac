"""Client-only report-count presentation. Never jitter, infer identities or locations."""

cl def:pub aggregate_places(rows: list[dict], anchors: list = []) -> list[dict] {
    groups: dict[str, dict] = {};
    for row in rows {
        if not Number.isFinite(row["longitude"]) or not Number.isFinite(row["latitude"]) { continue; }
        longitude: float = row["longitude"];
        latitude: float = row["latitude"];
        if abs(longitude) > 180 or abs(latitude) > 90 { continue; }
        if row["longitude"] == 0 and row["latitude"] == 0 { continue; }
        if not Number.isSafeInteger(row["report_count"]) or row["report_count"] <= 0 { continue; }
        key = JSON.stringify([row["longitude"], row["latitude"]]);
        if key not in groups {
            name = row["name"];
            for anchor in anchors {
                if anchor.geometry.type == "Point" and anchor.geometry.coordinates[0] == row["longitude"] and anchor.geometry.coordinates[1] == row["latitude"] {
                    name = anchor.properties.label;
                }
            }
            groups[key] = {"key": key, "name": name, "longitude": row["longitude"],
                "latitude": row["latitude"], "report_count": 0, "missing": 0, "safe": 0, "other": 0,
                "location_ids": []};
        }
        group = groups[key];
        group["report_count"] = int(group["report_count"]) + int(row["report_count"]);
        for field in ["missing", "safe", "other"] {
            if Number.isSafeInteger(row[field]) and row[field] >= 0 { group[field] = int(group[field]) + int(row[field]); }
        }
        group["location_ids"].append(row["location_id"]);
    }
    result: list[dict] = list(groups.values());
    return sorted(result, key=lambda (g: dict) -> int { return -int(g["report_count"]); });
}

cl def:pub density_geojson(groups: list[dict]) -> dict {
    return {"type": "FeatureCollection", "features": [
        {"type": "Feature", "geometry": {"type": "Point", "coordinates": [g["longitude"], g["latitude"]]},
         "properties": {"key": g["key"], "name": g["name"], "report_count": g["report_count"],
             "missing": g["missing"], "safe": g["safe"], "other": g["other"]}} for g in groups
    ]};
}
