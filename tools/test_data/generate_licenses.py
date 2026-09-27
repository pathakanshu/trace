#!/usr/bin/env python3
"""Convert the existing usage inventory to the specified per-Media contract.

No rights are granted or broadened. Original generator/encoder version was not
recorded; that unknown is explicit. Private family IDs/recipes are never emitted.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import stat
import tempfile
from generate_queries import ROOT,DATASET,read_catalog,strict_json_loads
from repair_media_time import generation_start,safe_file
from unpack_assets import confined_target

USAGE_BASIS='Internal exercise assets; redistribution requires project owner review.'
ATTRIBUTION='Trace exercise dataset generation tooling'
UNKNOWN_VERSION='not recorded'


def build_licenses(catalog,families,receipt):
    stamp=generation_start(receipt);media={key:row for key,row in catalog.items() if row['kind']=='media'}
    measured={row['media_id']:row for row in receipt['images']}
    if len(measured)!=len(receipt['images']) or set(measured)!=set(media):raise ValueError('Receipt does not cover exactly the catalog media')
    members={}
    for family in families:
        for member in family['members']:
            ident=member['media_id']
            if ident in members:raise ValueError('Media family member repeats')
            if member['operation'] not in ('base','byte_copy','resize','reencode','crop'):raise ValueError('Unknown asset origin')
            members[ident]=member
    if set(members)!=set(media):raise ValueError('Family inventory must partition all media')
    assets=[]
    for ident,row in sorted(media.items()):
        if row['actual_created_at']!=stamp:raise ValueError(ident+': reconcile creation metadata with original receipt first')
        if row['sha256']!=measured[ident]['sha256'] or row['asset_path']!=measured[ident]['path']:raise ValueError(ident+': receipt differs from catalog')
        assets.append({'license_id':row['license_id'],'media_id':ident,
            'origin':'generated' if members[ident]['operation']=='base' else 'derived',
            'tool':{'name':receipt['generator'],'version':UNKNOWN_VERSION},
            'actual_created_at':stamp,'usage_basis':USAGE_BASIS,'attribution':ATTRIBUTION,
            'source_reference':'tools/test_data/generate_assets.py','artifact_sha256':row['sha256'],
            'limitations':['Fictional procedural placeholder, not documentary imagery of the historical event.',
                'Original Pillow/encoder version was not recorded; tool.version states that unknown explicitly.',
                'Creation time is the original asset-generation run start, not a capture time or file mtime.',
                'Embedded fixture metadata is controlled and does not establish location or authenticity.']})
    return {'dataset_id':DATASET,'assets':assets}


def validate_licenses(value,catalog,families,receipt):
    expected=build_licenses(catalog,families,receipt)
    if not isinstance(value,dict) or set(value)!={'dataset_id','assets'} or not isinstance(value['assets'],list):raise ValueError('License inventory differs from closed contract')
    ids=[row.get('media_id') for row in value['assets'] if isinstance(row,dict)]
    if len(ids)!=len(value['assets']) or len(ids)!=len(set(ids)):raise ValueError('License entries require unique Media IDs')
    if value!=expected:raise ValueError('License entries differ from measured catalog provenance or preserved usage basis')
    return {'entries':len(ids),'origins':dict(Counter(row['origin'] for row in value['assets'])),
            'original_encoder_version_recorded':False}


def write_licenses(root):
    root=root.resolve();data=root/'demo/datasets'/DATASET;fixtures=root/'tests/fixtures'/DATASET
    catalog=read_catalog(root)
    receipt=strict_json_loads(safe_file(data/'asset-measurements.json',data).read_text(encoding='utf-8'))
    family_path=safe_file(fixtures/'oracle/media-families.jsonl',fixtures)
    families=[strict_json_loads(line) for line in family_path.read_text(encoding='utf-8').splitlines()]
    result=build_licenses(catalog,families,receipt);observed=validate_licenses(result,catalog,families,receipt)
    for item in result['assets']:
        row=catalog[item['media_id']];payload=confined_target(root,row['asset_path']).read_bytes()
        if hashlib.sha256(payload).hexdigest()!=item['artifact_sha256'] or len(payload)!=row['byte_size']:raise ValueError(row['id']+': actual asset integrity mismatch')
    target=safe_file(data/'licenses.json',data);existing=strict_json_loads(target.read_text(encoding='utf-8'))
    if isinstance(existing,list):
        if len(existing)!=1 or existing[0].get('terms')!=USAGE_BASIS or existing[0].get('creator')!=ATTRIBUTION:raise ValueError('Unexpected legacy terms; refusing to change usage basis')
    else:validate_licenses(existing,catalog,families,receipt)
    payload=(json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    if target.read_bytes()==payload:return {**observed,'files_changed':0}
    temporary=None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent,prefix='.licenses-',delete=False) as stream:
            temporary=Path(stream.name);stream.write(payload)
        temporary.chmod(stat.S_IMODE(target.stat().st_mode));temporary.replace(target)
    finally:
        if temporary is not None:temporary.unlink(missing_ok=True)
    return {**observed,'files_changed':1}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT)
    print(json.dumps(write_licenses(parser.parse_args().root)))
