#!/usr/bin/env python3
"""Verify the published ZIP and every member before restoring ignored media."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "demo/datasets/bhotekoshi-2016-exercise-v1"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 tools/test_data/unpack_assets.py <downloaded-assets.zip>")
    bundle = Path(sys.argv[1])
    distribution = json.loads((DATA / "asset-distribution.json").read_text())
    raw = bundle.read_bytes()
    if len(raw) != distribution["byte_size"] or sha(raw) != distribution["sha256"]:
        raise ValueError("Bundle size/SHA-256 mismatch; no files written")
    manifest = json.loads((DATA / "manifest.json").read_text())
    expected = {item["path"]: item for item in manifest["assets"]}
    pending = []
    with zipfile.ZipFile(bundle) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(expected):
            raise ValueError("ZIP inventory differs from manifest; no files written")
        for name in names:
            target = (ROOT / name).resolve()
            allowed = (ROOT / "demo/assets/bhotekoshi-2016-exercise-v1").resolve()
            if not target.is_relative_to(allowed):
                raise ValueError("Asset path escapes expected directory")
            content = archive.read(name)
            spec = expected[name]
            if len(content) != spec["byte_size"] or sha(content) != spec["sha256"]:
                raise ValueError("Asset integrity mismatch: " + name)
            if target.exists() and target.read_bytes() != content:
                raise ValueError("Refusing to overwrite changed asset: " + name)
            pending.append((target, content))
    for target, content in pending:
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
    print(f"Verified and restored {len(pending)} files (200 images + 200 thumbnails).")

if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
