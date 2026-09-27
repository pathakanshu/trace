"""Prepare supplied PNGs and MOV clips for Trace; never modify the originals.

Usage: python3 tools/prepare_community_media.py /path/to/originals
Requires ffmpeg/ffprobe only when preparing media, not when running Trace.
PNG bytes are copied unchanged. MOV clips become labelled H.264 playback copies.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets' / 'community-media'
MANIFEST = ROOT / 'features' / 'media' / 'community-manifest.json'


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries',
        'format=duration:stream=codec_name,codec_type,width,height', '-of', 'json', str(path)]))


def prepare(source):
    if MANIFEST.exists() or DEST.exists():
        raise SystemExit('Output already exists. Preserve the published package; choose a new version before replacing it.')
    files = sorted(p for p in source.iterdir() if p.is_file() and p.suffix.lower() in {'.png', '.mov'})
    if not files:
        raise SystemExit('No PNG or MOV files found.')
    added = datetime.now(timezone.utc).isoformat()
    rows = []
    for index, original in enumerate(files):
        digest = sha(original)
        video = original.suffix.lower() == '.mov'
        kind = 'video' if video else 'image'
        number = 1 + sum(r['media_type'] == kind for r in rows)
        asset_id = 'supplied-' + digest
        filename = f'{kind}-{number:02d}-{digest[:12]}'
        target = DEST / (filename + ('.mp4' if video else '.png'))
        target.parent.mkdir(parents=True, exist_ok=True)
        poster = ''
        duration = 0.0
        if video:
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(original),
                '-map', '0:v:0', '-map', '0:a?', '-vf',
                "scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,fps=30",
                '-c:v', 'libx264', '-crf', '23', '-preset', 'fast', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '128k', '-map_metadata', '-1', '-movflags', '+faststart', str(target)], check=True)
            info = probe(target)
            stream = next(s for s in info['streams'] if s['codec_type'] == 'video')
            width, height = stream['width'], stream['height']
            duration = float(info['format']['duration'])
            poster_file = DEST / (filename + '-thumb.jpg')
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-ss', '0.1', '-i', str(target),
                            '-frames:v', '1', '-vf', 'scale=640:640:force_original_aspect_ratio=decrease',
                            '-q:v', '4', str(poster_file)], check=True)
            poster = '/assets/community-media/' + poster_file.name
            conversion = 'H.264 MP4 playback copy, fitted within 1280px, 30fps; original MOV preserved separately.'
        else:
            shutil.copy2(original, target)
            width, height = struct.unpack('>II', target.read_bytes()[16:24])
            assert sha(target) == digest
            poster_file = DEST / (filename + '-thumb.jpg')
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(target),
                            '-frames:v', '1', '-vf', 'scale=640:640:force_original_aspect_ratio=decrease',
                            '-q:v', '4', str(poster_file)], check=True)
            poster = '/assets/community-media/' + poster_file.name
            conversion = 'Original PNG bytes, unchanged.'
        row = {'asset_id': asset_id, 'title': ('Clip' if video else 'Photo') + f' {number:02d}',
               'media_type': kind, 'url': '/assets/community-media/' + target.name,
               'poster_url': poster, 'original_filename': original.name,
               'original_sha256': digest, 'original_bytes': original.stat().st_size,
               'sha256': sha(target), 'bytes': target.stat().st_size,
               'width': width, 'height': height, 'duration_seconds': duration,
               'added_at': added, 'order': index, 'conversion': conversion,
               'source_reference': 'User supplied; original source, recording date and location unverified.'}
        row['poster_sha256'] = sha(poster_file)
        row['poster_bytes'] = poster_file.stat().st_size
        rows.append(row)
        print(row['title'], row['bytes'], flush=True)
    result = {'version': 1, 'collection': 'User-supplied review media', 'added_at': added,
              'note': 'Shared review library. These files are not verified evidence for any selected incident.',
              'items': rows}
    MANIFEST.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print('Prepared', len(rows), 'items;', sum(r['bytes'] for r in rows), 'playback bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('originals', type=Path)
    prepare(parser.parse_args().originals.resolve())
