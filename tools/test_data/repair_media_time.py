#!/usr/bin/env python3
"""Repair only catalog-run time mistaken for the recorded asset-run start time.

Preflight all destinations and actual asset hashes before writing. This is not a
corpus regenerator or a transaction against concurrent edits: use an idle data
checkout. Sources, claims, asset files and the receipt itself are never written.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import stat
import tempfile
from datetime import datetime
from generate_queries import ROOT,DATASET,read_catalog,strict_json_loads
from unpack_assets import confined_target


def generation_start(receipt):
    stamp=receipt.get('generated_at')
    if receipt.get('dataset_id')!=DATASET or receipt.get('generator')!='Pillow controlled placeholder scenes':
        raise ValueError('Unrecognized original asset-run receipt')
    if not isinstance(stamp,str) or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ',stamp):
        raise ValueError('Asset-run receipt needs its recorded UTC start time')
    datetime.fromisoformat(stamp.replace('Z','+00:00'))
    return stamp


def correct_media_rows(rows,receipt,legacy_time):
    stamp=generation_start(receipt);items=receipt['images'];measured={r['media_id']:r for r in items}
    if len(measured)!=len(items) or set(measured)!={r['id'] for r in rows} or len(rows)!=len(measured):
        raise ValueError('Receipt must cover every media record exactly once')
    result=[]
    for row in rows:
        if row['kind']!='media':raise ValueError('Repair accepts only Media records')
        if row['actual_created_at'] not in (legacy_time,stamp):raise ValueError('Unexpected existing creation time; refusing to infer a replacement')
        observed=measured[row['id']]
        for key in ('sha256','byte_size','width_px','height_px','mime_type'):
            if row[key]!=observed[key]:raise ValueError(row['id']+': receipt differs from catalog '+key)
        if row['asset_path']!=observed['path']:raise ValueError(row['id']+': receipt asset path differs')
        changed=copy.deepcopy(row);changed['actual_created_at']=stamp;result.append(changed)
    return result


def safe_file(path,allowed):
    if not path.resolve().is_relative_to(allowed) or path.is_symlink():raise ValueError('Repair path escapes allowed directory or is a symlink')
    if not path.is_file():raise ValueError('Repair input/destination must be an existing file')
    return path


def plan_repair(root):
    root=root.resolve();data=root/'demo/datasets'/DATASET;hero=root/'tests/fixtures'/DATASET/'hero'
    def load(path,allowed=data):return strict_json_loads(safe_file(path,allowed).read_text(encoding='utf-8'))
    receipt=load(data/'asset-measurements.json');legacy_time=load(data/'generation-status.json')['generated_at']
    manifest=load(data/'manifest.json');quota=load(root/'demo/spec/quotas.json',root/'demo/spec')
    if receipt['seed']!=quota['seed']:raise ValueError('Receipt seed differs from dataset allocation')
    catalog=read_catalog(root);media=[r for r in catalog.values() if r['kind']=='media']
    if len(media)!=quota['images']['uploads']:raise ValueError('Media count differs from quota')
    corrected=correct_media_rows(media,receipt,legacy_time);by_id={r['id']:r for r in corrected}
    inventory=manifest['assets'];paths=[item['path'] for item in inventory]
    if len(paths)!=len(set(paths)) or len(paths)!=2*len(media):raise ValueError('Invalid asset inventory coverage')
    expected={r[key] for r in media for key in ('asset_path','thumbnail_path')}
    if set(paths)!=expected:raise ValueError('Inventory does not cover exactly the catalog images and thumbnails')
    for item in inventory:
        path=confined_target(root,item['path']);payload=path.read_bytes()
        if len(payload)!=item['byte_size'] or hashlib.sha256(payload).hexdigest()!=item['sha256']:
            raise ValueError('Actual asset bytes differ from manifest; repair aborted')
    pending={};media_paths=sorted((data/'records/media').glob('*.jsonl'));seen=[]
    def encoded(rows):return (''.join(json.dumps(r,ensure_ascii=False,separators=(',',':'))+'\n' for r in rows)).encode('utf-8')
    for path in media_paths:
        safe_file(path,data/'records/media');rows=[strict_json_loads(line) for line in path.read_text(encoding='utf-8').splitlines()]
        if any(r['kind']!='media' for r in rows):raise ValueError('Media shard contains another record kind')
        seen.extend(r['id'] for r in rows);pending[path]=encoded([by_id[r['id']] for r in rows])
    if set(seen)!=set(by_id) or len(seen)!=len(by_id):raise ValueError('Media shard coverage mismatch')
    shard_entries={item['path']:item for item in manifest['record_shards']}
    if len(shard_entries)!=len(manifest['record_shards']):raise ValueError('Duplicate manifest shard inventory')
    for path,payload in pending.items():
        item=shard_entries[path.relative_to(root).as_posix()];original=path.read_bytes()
        if item['sha256']!=hashlib.sha256(original).hexdigest() or item['byte_size']!=len(original):raise ValueError('Manifest shard checksum is stale; refusing repair')
        item['sha256']=hashlib.sha256(payload).hexdigest();item['byte_size']=len(payload)
    hero_media=0
    for path in sorted(hero.glob('*.jsonl')):
        safe_file(path,hero);rows=[strict_json_loads(line) for line in path.read_text(encoding='utf-8').splitlines()]
        if any(r!=catalog.get(r['id']) for r in rows):raise ValueError('Hero rows differ from the full catalog before repair')
        if not any(r['kind']=='media' for r in rows):continue
        hero_media+=sum(r['kind']=='media' for r in rows)
        pending[path]=encoded([by_id[r['id']] if r['kind']=='media' else r for r in rows])
    if not hero_media:raise ValueError('Missing existing hero media selection')
    pending[data/'manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    changed={path:payload for path,payload in pending.items() if path.read_bytes()!=payload}
    return changed,{'media_records_changed':sum(a!=b for a,b in zip(media,corrected)),
                    'hero_media_records_selected':hero_media,'files_changed':len(changed),
                    'asset_files_verified':len(inventory),'recorded_asset_run_start':generation_start(receipt),
                    'replaced_catalog_run_time':legacy_time}


def repair(root):
    pending,report=plan_repair(root)
    for path,payload in pending.items():
        temporary=None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent,prefix='.media-time-',delete=False) as stream:
                temporary=Path(stream.name);stream.write(payload)
            temporary.chmod(stat.S_IMODE(path.stat().st_mode))
            temporary.replace(path)
        finally:
            if temporary is not None:temporary.unlink(missing_ok=True)
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--write',action='store_true')
    args=parser.parse_args();print(json.dumps(repair(args.root) if args.write else plan_repair(args.root)[1]))
