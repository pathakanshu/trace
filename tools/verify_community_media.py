"""Audit the shipped media against measured bytes, hashes and ffprobe properties.

Run with --originals /path/to/originals to also verify preserved source files.
Requires ffprobe for this audit only; no network, model or database access.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'community-media'
MANIFEST = ROOT / 'features' / 'media' / 'community-manifest.json'


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def check_file(url, expected_hash, expected_bytes):
    path = (ROOT / url.lstrip('/')).resolve()
    assert path.parent == ASSETS.resolve(), f'Unexpected asset path: {url}'
    assert path.is_file(), f'Missing asset: {url}'
    assert path.stat().st_size == expected_bytes, f'Size mismatch: {url}'
    assert sha(path) == expected_hash, f'Hash mismatch: {url}'
    return path


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries',
        'format=duration:stream=codec_name,codec_type,width,height', '-of', 'json', str(path)]))


def fast_start(path):
    """MP4 metadata must precede payload so playback need not fetch the whole file."""
    with path.open('rb') as handle:
        while handle.tell() < path.stat().st_size:
            start = handle.tell()
            size, kind = struct.unpack('>I4s', handle.read(8))
            if size == 1:
                size = struct.unpack('>Q', handle.read(8))[0]
            if kind == b'moov':
                return True
            if kind == b'mdat' or size < 8:
                return False
            handle.seek(start + size)
    return False


def verify(originals=None):
    items = json.loads(MANIFEST.read_text())['items']
    assert Counter(item['media_type'] for item in items) == {'image': 20, 'video': 9}
    assert len({item['asset_id'] for item in items}) == 29
    assert len({item['order'] for item in items}) == 29
    assert len({item['original_filename'] for item in items}) == 29
    expected_files = set()
    for item in items:
        assert item['asset_id'] == 'supplied-' + item['original_sha256']
        media = check_file(item['url'], item['sha256'], item['bytes'])
        thumbnail = check_file(item['poster_url'], item['poster_sha256'], item['poster_bytes'])
        expected_files.update([media, thumbnail])
        thumb = probe(thumbnail)['streams'][0]
        assert thumb['codec_name'] == 'mjpeg' and max(thumb['width'], thumb['height']) <= 640
        info = probe(media)
        stream = next(s for s in info['streams'] if s['codec_type'] == 'video')
        assert (stream['width'], stream['height']) == (item['width'], item['height'])
        if item['media_type'] == 'video':
            assert stream['codec_name'] == 'h264' and max(stream['width'], stream['height']) <= 1280
            assert abs(float(info['format']['duration']) - item['duration_seconds']) < 0.01
            assert fast_start(media), f'MP4 is missing fast-start metadata: {media.name}'
        else:
            assert stream['codec_name'] == 'png'
            assert item['sha256'] == item['original_sha256']
        if originals:
            source = (originals / item['original_filename']).resolve()
            assert source.parent == originals.resolve()
            assert source.stat().st_size == item['original_bytes']
            assert sha(source) == item['original_sha256']
    assert expected_files == {p.resolve() for p in ASSETS.iterdir() if p.is_file()}
    return {'status': 'PASS', 'photos': 20, 'videos': 9, 'thumbnails': 29,
            'playback_bytes': sum(item['bytes'] for item in items),
            'thumbnail_bytes': sum(item['poster_bytes'] for item in items),
            'original_bytes': sum(item['original_bytes'] for item in items),
            'originals_checked': originals is not None, 'manifest_sha256': sha(MANIFEST)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--originals', type=Path)
    print(json.dumps(verify(parser.parse_args().originals), indent=2))
