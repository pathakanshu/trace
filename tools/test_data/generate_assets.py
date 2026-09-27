#!/usr/bin/env python3
"""Create deterministic, visibly synthetic placeholder media for the exercise."""

from __future__ import annotations

import hashlib
import json
import random
import shutil
import zipfile
import tempfile
from fractions import Fraction
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DATASET = "bhotekoshi-2016-exercise-v1"
ASSET_ROOT = ROOT / "demo/assets" / DATASET
OUTPUT_ROOT = ROOT / "demo/datasets" / DATASET
ORACLE_ROOT = ROOT / "tests/fixtures" / DATASET / "oracle"
SEED = 20160705
STAMP = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
CATEGORIES = [("infrastructure_access", 35), ("hazards", 25), ("facilities_aid", 25),
              ("notices_documents", 20), ("possessions_illustrations", 15)]
ANCHORS = [(27.9646238, 85.9568747), (27.9448408, 85.9490115),
           (27.7878060, 85.8995820), (27.7543053, 85.8269035)]
PALETTE = ["#41677a", "#637c65", "#bf8a50", "#7d6861", "#607d91", "#87906a"]


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def scene(index: int, category: str) -> Image.Image:
    rng = random.Random(SEED + index * 7919)
    im = Image.new("RGB", (1600, 1200), (220, 225, 218))
    d = ImageDraw.Draw(im)
    sky = rng.choice(["#cbd8d8", "#d5d7ce", "#bccbd0", "#d8cfc0"])
    d.rectangle((0, 0, 1600, 820), fill=sky)
    for layer, color in [(0, "#71847a"), (1, "#566e6c"), (2, "#405a5e")]:
        points, x = [(-100, 750)], -100
        while x <= 1700:
            points.extend([(x + 150, rng.randint(330 + layer * 80, 720 + layer * 30)),
                           (x + 310, 755 + layer * 25)])
            x += 310
        points.extend([(1700, 900), (-100, 900)])
        d.polygon(points, fill=color)
    d.polygon([(0, 840), (350, 740), (680, 900), (1000, 735),
               (1600, 850), (1600, 1200), (0, 1200)], fill="#78856b")
    d.polygon([(530, 790), (790, 810), (925, 1200), (380, 1200)], fill="#799da5")
    d.line([(650, 835), (610, 970), (700, 1100), (655, 1200)], fill="#d0d8cf", width=10)
    accent = rng.choice(PALETTE)
    if category == "infrastructure_access":
        d.polygon([(0, 955), (380, 850), (465, 915), (40, 1080)], fill="#887a69")
        d.line([(60, 1010), (400, 905)], fill="#d5c6a5", width=12)
        if index % 2 == 0:
            d.rectangle((475, 762, 1110, 800), fill=accent)
            for x in range(500, 1111, 100): d.rectangle((x, 800, x + 14, 950), fill="#594f45")
            d.line([(470, 752), (1120, 752)], fill="#e1d8c4", width=16)
        else:
            d.rectangle((920, 690, 1300, 1060), fill="#7c6956")
            d.rectangle((1000, 740, 1060, 805), fill="#d6c399")
    elif category == "hazards":
        for _ in range(24):
            x, y, r = rng.randint(180, 1400), rng.randint(750, 1140), rng.randint(12, 54)
            d.ellipse((x-r, y-r, x+r, y+r), fill=rng.choice(["#746b61", "#85776a", "#625e57"]))
        d.polygon([(0, 870), (300, 835), (620, 955), (650, 1200), (0, 1200)], fill="#887b68")
        d.line([(70, 930), (220, 1010), (330, 980), (500, 1120)], fill="#bd9b6e", width=23)
    elif category == "facilities_aid":
        d.rectangle((900, 590, 1370, 1030), fill="#d1c7ad")
        d.polygon([(850, 610), (1120, 410), (1430, 610)], fill=accent)
        for x in (970, 1130, 1280): d.rectangle((x, 700, x + 85, 850), fill="#72909a")
        d.rectangle((1070, 875, 1180, 1030), fill="#705a48")
        for _ in range(5):
            x = rng.randint(300, 700)
            d.rectangle((x, 990, x + 95, 1075), fill=rng.choice(["#bd9663", "#69816b", "#9e7557"]))
            d.line((x + 12, 1010, x + 83, 1010), fill="#e7dfc9", width=4)
    elif category == "notices_documents":
        d.rounded_rectangle((770, 430, 1330, 1060), radius=18, fill="#eee9db", outline="#695f50", width=12)
        d.rectangle((850, 510, 1240, 560), fill=accent)
        for y in range(610, 940, 62): d.line((850, y, rng.randint(1080, 1240), y), fill="#9b978b", width=11)
        d.rectangle((250, 905, 600, 1030), fill="#c9b98e", outline="#6f6655", width=8)
    else:
        d.rounded_rectangle((650, 720, 1010, 1080), radius=78, fill=accent, outline="#3f4f50", width=18)
        d.arc((725, 660, 930, 850), 180, 360, fill="#374a4c", width=24)
        d.rectangle((740, 830, 925, 870), fill="#c3b899")
        d.ellipse((1120, 870, 1270, 1020), fill="#aa815c", outline="#5d5148", width=10)
    d.rectangle((0, 1120, 1600, 1200), fill="#f2eee2")
    d.text((34, 1145), "FICTIONAL EXERCISE ASSET / SYNTHETIC PLACEHOLDER", fill="#333b3c", font=ImageFont.load_default())
    d.text((1490, 1145), f"{index:03d}", fill="#333b3c", font=ImageFont.load_default())
    return im


def make_exif(mode: str, gps: tuple[float, float] | None) -> bytes:
    exif = Image.Exif()
    if mode != "no_exif":
        exif[305] = "Trace controlled exercise asset generator"
        exif[270] = "Synthetic placeholder; metadata is fictional test data"
    if gps is not None:
        def dms(value: float):
            absolute = abs(value); degree = int(absolute); mins = (absolute - degree) * 60
            minute = int(mins); second = round((mins - minute) * 60 * 10000)
            return (Fraction(degree, 1), Fraction(minute, 1), Fraction(second, 10000))
        exif[34853] = {1: "N" if gps[0] >= 0 else "S", 2: dms(gps[0]),
                       3: "E" if gps[1] >= 0 else "W", 4: dms(gps[1])}
    return exif.tobytes()


def main() -> None:
    images = ASSET_ROOT / "images"; thumbs = ASSET_ROOT / "thumbnails"
    images.mkdir(parents=True, exist_ok=True); thumbs.mkdir(parents=True, exist_ok=True)
    ORACLE_ROOT.mkdir(parents=True, exist_ok=True); OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    if any(images.iterdir()) or any(thumbs.iterdir()):
        raise SystemExit("Refusing to overwrite existing asset files; clear this versioned bundle explicitly.")
    bases = []
    categories = [cat for cat, count in CATEGORIES for _ in range(count)]
    for i, category in enumerate(categories, 1):
        media_id = f"med-{i:06d}"
        mode = "controlled_gps_exif" if i <= 36 else "non_gps_exif" if i <= 60 else "no_exif"
        gps = ANCHORS[(i - 1) % len(ANCHORS)] if mode == "controlled_gps_exif" else None
        image = scene(i, category); path = images / f"{media_id}.png"
        image.save(path, format="PNG", exif=make_exif(mode, gps))
        thumb = image.copy(); thumb.thumbnail((320, 320), Image.Resampling.LANCZOS)
        thumb.save(thumbs / f"{media_id}.webp", format="WEBP", quality=82)
        bases.append({"media_id": media_id, "path": path, "category": category, "metadata": mode})

    families = []; family_index = 0; next_id = 121
    for family_class, operation, count in [("base_plus_exact_copy", "byte_copy", 40),
                                            ("base_plus_resize", "resize", 20),
                                            ("base_plus_reencode", "reencode", 10),
                                            ("base_plus_crop", "crop", 10)]:
        for _ in range(count):
            base = bases[family_index]; family_index += 1; new_id = f"med-{next_id:06d}"; next_id += 1
            src = base["path"]
            if operation == "byte_copy":
                target = images / f"{new_id}.png"; shutil.copyfile(src, target)
                params = {"width_px": None, "height_px": None, "jpeg_quality": None, "crop_box": None,
                          "metadata_policy": "preserve", "embedded_exif": [], "generation_tool": None, "generation_prompt": None}
            else:
                image = Image.open(src).convert("RGB")
                if operation == "resize":
                    image = image.resize((1280, 960), Image.Resampling.LANCZOS); quality = None; crop = None
                elif operation == "reencode": quality = 72; crop = None
                else: quality = 78; crop = [160, 120, 1440, 1080]; image = image.crop(tuple(crop))
                target = images / f"{new_id}.jpg"
                image.save(target, format="JPEG", quality=quality or 86, optimize=True)
                params = {"width_px": 1280 if operation == "resize" else None,
                          "height_px": 960 if operation == "resize" else None, "jpeg_quality": quality,
                          "crop_box": crop, "metadata_policy": "strip", "embedded_exif": [],
                          "generation_tool": None, "generation_prompt": None}
            thumb = Image.open(target).convert("RGB"); thumb.thumbnail((320, 320), Image.Resampling.LANCZOS)
            thumb.save(thumbs / f"{new_id}.webp", format="WEBP", quality=82)
            base_member = {"media_id": base["media_id"], "parent_media_id": None, "operation": "base",
                "parameters": {"width_px": None, "height_px": None, "jpeg_quality": None, "crop_box": None,
                  "metadata_policy": "controlled_write" if base["metadata"] != "no_exif" else "strip",
                  "embedded_exif": [], "generation_tool": "Pillow controlled vector scene", "generation_prompt": base["category"]}}
            copy_member = {"media_id": new_id, "parent_media_id": base["media_id"], "operation": operation, "parameters": params}
            families.append({"id": f"fam-{family_index:06d}", "base_media_id": base["media_id"],
                "family_class": family_class, "content_category": base["category"], "base_metadata": base["metadata"],
                "members": [base_member, copy_member], "unrelated_lookalike_family_ids": [], "tags": []})
    for base in bases[80:]:
        family_index += 1
        families.append({"id": f"fam-{family_index:06d}", "base_media_id": base["media_id"],
            "family_class": "singleton", "content_category": base["category"], "base_metadata": base["metadata"],
            "members": [{"media_id": base["media_id"], "parent_media_id": None, "operation": "base",
                "parameters": {"width_px": None, "height_px": None, "jpeg_quality": None, "crop_box": None,
                 "metadata_policy": "controlled_write" if base["metadata"] != "no_exif" else "strip",
                 "embedded_exif": [], "generation_tool": "Pillow controlled vector scene", "generation_prompt": base["category"]}}],
            "unrelated_lookalike_family_ids": [], "tags": []})
    for i in range(10):
        a, b = families[-40 + i * 2], families[-39 + i * 2]
        a["unrelated_lookalike_family_ids"].append(b["id"]); b["unrelated_lookalike_family_ids"].append(a["id"])
        a["tags"].append("unrelated_lookalike_negative_pair"); b["tags"].append("unrelated_lookalike_negative_pair")
    by_base = {int(item["base_media_id"][-6:]): item for item in families}
    for media_no in range(1, 13): by_base[media_no]["tags"].append("gps_caption_conflict")
    for media_no in range(1, 11): by_base[media_no]["tags"].append("misleading_exact_copy_caption")
    for media_no in range(41, 51): by_base[media_no]["tags"].append("misleading_resized_copy_caption")
    for media_no in [1, 2, 41, 42, 61]: by_base[media_no]["tags"].append("earliest_publication_ingested_last")
    (ORACLE_ROOT / "media-families.jsonl").write_text(
        "".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n" for item in families), encoding="utf-8")
    actual = []
    for path in sorted(images.iterdir()):
        with Image.open(path) as image:
            exif = image.getexif(); gps = exif.get_ifd(34853) if 34853 in exif else {}
            actual.append({"media_id": path.stem, "path": path.relative_to(ROOT).as_posix(), "sha256": digest(path),
                "byte_size": path.stat().st_size, "mime_type": Image.MIME.get(image.format, "image/" + image.format.lower()),
                "width_px": image.width, "height_px": image.height, "exif_present": bool(exif), "gps_present": bool(gps)})
    (OUTPUT_ROOT / "asset-measurements.json").write_text(json.dumps({"dataset_id": DATASET, "generated_at": STAMP,
        "generator": "Pillow controlled placeholder scenes", "seed": SEED, "images": actual}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sheet = Image.new("RGB", (8 * 210, 25 * 178), (248, 248, 244)); draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(sorted(images.iterdir())):
        thumb = Image.open(thumbs / f"{path.stem}.webp").convert("RGB"); thumb.thumbnail((200, 148))
        x, y = (index % 8) * 210, (index // 8) * 178
        sheet.paste(thumb, (x + (200-thumb.width)//2, y)); draw.text((x+5, y+150), path.stem, fill=(20, 30, 35))
    sheet.save(OUTPUT_ROOT / "contact-sheet.png", format="PNG", optimize=True)
    archive = Path(tempfile.gettempdir()) / f"{DATASET}-assets.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for path in sorted([*images.iterdir(), *thumbs.iterdir()]): zf.write(path, path.relative_to(ROOT).as_posix())
    print(json.dumps({"base_scenes": len(bases), "uploads": len(actual), "families": len(families),
        "unique_sha256": len({item['sha256'] for item in actual}),
        "base_metadata": {mode: sum(b['metadata'] == mode for b in bases) for mode in sorted({b['metadata'] for b in bases})},
        "image_bytes": sum(item['byte_size'] for item in actual), "archive": str(archive),
        "archive_sha256": digest(archive), "archive_bytes": archive.stat().st_size,
        "gps_tagged_uploads": sum(item['gps_present'] for item in actual)}, indent=2))


if __name__ == "__main__": main()
