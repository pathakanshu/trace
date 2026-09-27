#!/usr/bin/env python3
"""Build sourced history/geography context from the preserved OSM response."""

from __future__ import annotations

import gzip
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET_ROOT = ROOT / "demo/datasets/bhotekoshi-2016-exercise-v1"
CONTEXT = DATASET_ROOT / "context"
OSM_PATH = CONTEXT / "geographic-inputs/overpass-corridor-20260927.json.gz"
NOW = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
OSM_URL = "https://overpass-api.de/api/interpreter"
OSM_LICENSE_URL = "https://www.openstreetmap.org/copyright"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def time_record(date: str, precision: str, original: str) -> dict:
    return {"value": None, "date": date, "precision": precision, "original_text": original,
            "timezone": "Asia/Kathmandu", "range_start": None, "range_end": None}


def main() -> None:
    if not OSM_PATH.exists():
        raise SystemExit(f"Missing preserved upstream geographic input: {OSM_PATH}")
    with gzip.open(OSM_PATH, "rt", encoding="utf-8") as stream:
        osm = json.load(stream)
    source_hash = sha256(OSM_PATH)
    osm_timestamp = osm["osm3s"]["timestamp_osm_base"]
    geometry_epoch = osm_timestamp[:10]
    elements = { (item["type"], item["id"]): item for item in osm["elements"] }

    historical = [
        {"id": "hist-000001", "url": "https://www.icimod.org/article/after-bhotekoshi/",
         "title": "After Bhotekoshi", "publisher": "International Centre for Integrated Mountain Development",
         "publication_date": "2016-07-13", "retrieval_date": "2026-09-27",
         "supported_statement": "ICIMOD reported that the 5 July flood swept away more than 50 houses, put about 200 more at risk, damaged the Kodari–Jure road corridor and affected hydropower; it said timely evacuation meant no lives were lost. Its account described the cause as not yet established and discussed a possible upstream landslide-dam breach.",
         "passage_or_figure": "Article paragraphs beginning ‘The recent floods in the Bhotekoshi River’ and ‘Though the exact cause of the flood’.",
         "event_time": time_record("2016-07-05", "night", "5 July 2016 flood; contemporaneous report does not give an onset clock time"),
         "scope_and_uncertainty": "Contemporaneous published account. The cause is explicitly uncertain in this publication; later reconstructions are not 2016 operational knowledge."},
        {"id": "hist-000002", "url": "https://icimod.org/caught-amidst-a-flash-flood-in-bahrabise",
         "title": "Caught amidst a flash flood in Bahrabise", "publisher": "International Centre for Integrated Mountain Development",
         "publication_date": "2016-08-29", "retrieval_date": "2026-09-27",
         "supported_statement": "A later field account describes the river corridor, settlements, infrastructure and local preparedness observations; it also recounts a separate intense rain and debris-flow episode during the field visit.",
         "passage_or_figure": "Opening event summary; paragraphs describing Jure, the bridge at Bahrabise, and the later field-visit rain episode.",
         "event_time": time_record("2016-07-05", "night", "5 July 2016 flood mentioned retrospectively"),
         "scope_and_uncertainty": "Do not attribute the field visit's later rainfall/debris-flow episode to 5 July. This source supports corridor context and later observations, not a complete July event timeline."},
        {"id": "hist-000003", "url": "https://www.icimod.org/when-the-levee-breaks-reducing-glof-risks-through-dam-breach-modelling/",
         "title": "When the levee breaks: Reducing GLOF risks through dam breach modelling", "publisher": "International Centre for Integrated Mountain Development",
         "publication_date": "2019-05-16", "retrieval_date": "2026-09-27",
         "supported_statement": "ICIMOD reported a retrospective DHM analysis identifying a glacial lake outburst flood in Tibet as the cause of the 2016 event.",
         "passage_or_figure": "Paragraph beginning ‘The 2016 Bhote Koshi floods put the lives…’.",
         "event_time": time_record("2016-07-05", "night", "night of 5 July 2016"),
         "scope_and_uncertainty": "Retrospective finding published in 2019; must not appear as available to a July 2016 source."},
        {"id": "hist-000004", "url": "https://www.nature.com/articles/s41598-022-16337-6",
         "title": "Transition of a small Himalayan glacier lake outburst flood to a giant transborder flood and debris flow", "publisher": "Scientific Reports",
         "publication_date": "2022-07-20", "retrieval_date": "2026-09-27",
         "supported_statement": "The paper reconstructs the 5 July 2016 event as originating at Gongbatongsha Lake in the Poiqu basin and describes its transboundary path and modeled downstream impacts.",
         "passage_or_figure": "Abstract; section ‘The 2016 GLOF’; Figure 1 caption.",
         "event_time": time_record("2016-07-05", "night", "night of 5 July 2016"),
         "scope_and_uncertainty": "Retrospective multi-model reconstruction, not contemporaneous telemetry. Modeled depth, velocity and extent are not used as observed geographic inputs for this exercise."},
    ]
    CONTEXT.mkdir(parents=True, exist_ok=True)
    (CONTEXT / "historical-references.jsonl").write_text(
        "".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n" for item in historical), encoding="utf-8")

    def props(label: str, kind: str, feature_id: str, refs: list[str], countries: list[str], limits: str):
        return {"label": label, "feature_type": kind, "historical_reference_ids": refs,
            "source_url": OSM_URL, "source_feature_id": feature_id, "source_version": osm_timestamp,
            "source_license": "Open Data Commons Open Database License 1.0 (ODbL-1.0), OpenStreetMap contributors",
            "source_license_url": OSM_LICENSE_URL,
            "use_conditions": "Attribute OpenStreetMap contributors and identify ODbL-1.0. Adapted database distributions remain subject to ODbL share-alike terms.",
            "source_artifact_path": OSM_PATH.relative_to(ROOT).as_posix(), "source_artifact_sha256": source_hash,
            "country_codes": countries, "coordinate_precision_m": None, "retrieved_at": NOW,
            "geometry_epoch": geometry_epoch, "uncertainty_m": None, "limitations": limits}

    features = []
    anchors = [(2257810269, "Kodari", ["hist-000001", "hist-000002"]),
               (296349536, "Tatopani", ["hist-000001", "hist-000002"]),
               (2257810264, "Bahrabise", ["hist-000001", "hist-000002"]),
               (11182726261, "Khadichaur", ["hist-000001", "hist-000002", "hist-000003"])]
    for i, (node_id, label, refs) in enumerate(anchors, start=2):
        node = elements.get(("node", node_id))
        if not node or "lat" not in node or "lon" not in node:
            raise SystemExit(f"Verified anchor missing from preserved OSM input: node/{node_id}")
        features.append({"type": "Feature", "id": f"geo-{i:06d}",
            "geometry": {"type": "Point", "coordinates": [node["lon"], node["lat"]]},
            "properties": props(label, "settlement", f"node/{node_id}", refs, ["NP"],
                "Current mapped settlement node. Coordinate accuracy and exact 2016 built-up extent are unknown; this is an anchor, not an approved reporting zone.")})

    river_ids = [144807631, 278789295, 291801629, 25141531]
    lines = []
    for way_id in river_ids:
        way = elements.get(("way", way_id))
        if not way or len(way.get("geometry", [])) < 2:
            raise SystemExit(f"Bhote Koshi segment missing or degenerate in preserved OSM input: way/{way_id}")
        lines.append([[point["lon"], point["lat"]] for point in way["geometry"]])
    # Keep independent surveyed OSM ways as MultiLineString members. Do not imply
    # hydrographic connectivity across unsurveyed gaps.
    features.append({"type": "Feature", "id": "geo-000001",
        "geometry": {"type": "MultiLineString", "coordinates": lines},
        "properties": props("Bhote Koshi mapped river segments", "river",
            ",".join(f"way/{way_id}" for way_id in river_ids), [], ["NP", "CN"],
            "Current OSM linework assembled as separate mapped ways; no measured 2016 flood extent, flow depth, discharge or continuous upstream geometry is claimed.")})
    features.sort(key=lambda feature: feature["id"])
    geojson = {"type": "FeatureCollection", "name": "Bhote Koshi exercise geographic context",
               "features": features}
    (CONTEXT / "geography.geojson").write_text(json.dumps(geojson, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(json.dumps({"historical_references": len(historical), "geography_features": len(features),
        "osm_snapshot": osm_timestamp, "osm_artifact_sha256": source_hash,
        "lamosanghu_anchor_found": False, "approved_reporting_zone_polygons_found": False}, indent=2))


if __name__ == "__main__": main()
