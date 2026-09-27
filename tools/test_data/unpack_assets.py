#!/usr/bin/env python3
"""Verify the preview ZIP and every member before restoring ignored media.

No application/database access. All inputs are preflighted before writing; this
is not a transaction against concurrent filesystem changes. Existing different
files are never overwritten. Only the primary image/thumbnail bundle is handled.
"""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import stat
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DATASET = 'bhotekoshi-2016-exercise-v1'
MAX_BYTES = 250 * 1024 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def confined_target(root, name):
    path = PurePosixPath(name)
    allowed = root / 'demo/assets' / DATASET
    if path.is_absolute() or '..' in path.parts or '\\' in name or path.as_posix() != name:
        raise ValueError('Invalid asset path: ' + name)
    target = root / name
    if not target.resolve().is_relative_to(allowed):
        raise ValueError('Asset path/symlink escapes expected directory: ' + name)
    for parent in target.parents:
        if parent == root: break
        if parent.exists() and not parent.is_dir():
            raise ValueError('Asset parent is not a directory: ' + name)
    if target.exists() and not target.is_file():
        raise ValueError('Asset destination is not a regular file: ' + name)
    return target


def restore_bundle(bundle, root=ROOT):
    root = root.resolve()
    data = root / 'demo/datasets' / DATASET
    distribution = json.loads((data / 'asset-distribution.json').read_text())
    expected_size = distribution['byte_size']
    if type(expected_size) is not int or not 0 < expected_size <= MAX_BYTES:
        raise ValueError('Bundle size is outside the primary asset budget')
    if bundle.stat().st_size != expected_size:
        raise ValueError('Bundle size/SHA-256 mismatch; no files written')
    raw = bundle.read_bytes()
    if len(raw) != expected_size or sha(raw) != distribution['sha256']:
        raise ValueError('Bundle size/SHA-256 mismatch; no files written')
    # The published preview still has its legacy manifest layout. Do not change
    # that distributed contract silently while fixing the independent unpacker.
    manifest = json.loads((data / 'manifest.json').read_text())
    entries = manifest['assets']
    expected = {item['path']: item for item in entries}
    if len(expected) != len(entries) or len(entries) != distribution['files']:
        raise ValueError('Manifest inventory duplicates/count mismatch; no files written')
    prefix = f'demo/assets/{DATASET}/'
    counts = {kind: sum(name.startswith(prefix + kind + '/') for name in expected) for kind in ('images','thumbnails')}
    if counts != {kind: distribution[kind] for kind in counts} or sum(counts.values()) != len(entries):
        raise ValueError('Image/thumbnail inventory differs from distribution')
    sizes = [item['byte_size'] for item in entries]
    if any(type(size) is not int or size <= 0 for size in sizes) or sum(sizes) > MAX_BYTES:
        raise ValueError('Uncompressed assets exceed the primary budget or have invalid sizes')
    pending = []
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        infos = archive.infolist()
        names = [info.filename for info in infos]
        if len(names) != len(set(names)) or set(names) != set(expected):
            raise ValueError('ZIP inventory differs from manifest; no files written')
        for info in sorted(infos, key=lambda item:item.filename):
            name = info.filename
            target = confined_target(root, name)
            mode = stat.S_IFMT(info.external_attr >> 16)
            if info.is_dir() or mode not in (0, stat.S_IFREG) or info.flag_bits & 1:
                raise ValueError('ZIP member must be an unencrypted regular file: ' + name)
            spec = expected[name]
            if info.file_size != spec['byte_size']:
                raise ValueError('ZIP declared size differs from manifest: ' + name)
            content = archive.read(info)
            if len(content) != spec['byte_size'] or sha(content) != spec['sha256']:
                raise ValueError('Asset integrity mismatch: ' + name)
            if target.exists() and target.read_bytes() != content:
                raise ValueError('Refusing to overwrite changed asset: ' + name)
            pending.append((name, content))
    for name, content in pending:
        target = confined_target(root, name)
        if target.exists():
            if target.read_bytes() != content:
                raise ValueError('Asset changed after preflight: ' + name)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target = confined_target(root, name)
        # Exclusive create prevents overwriting a new file/symlink appearing
        # after preflight. Concurrent writes are unsupported and may abort.
        with target.open('xb') as handle:
            handle.write(content)
    return {'files': len(pending), **counts}


def main():
    if len(sys.argv) != 2:
        raise ValueError('Usage: python3 tools/test_data/unpack_assets.py <downloaded-assets.zip>')
    counts = restore_bundle(Path(sys.argv[1]))
    print(f"Verified and restored {counts['files']} files ({counts['images']} images + {counts['thumbnails']} thumbnails).")


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
