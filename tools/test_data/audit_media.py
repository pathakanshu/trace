#!/usr/bin/env python3
"""Read-only measured media validation; never creates application evidence signals.

Requires Pillow only, independently of the schema environment. Recipe geometry
and exact bytes can be checked here; this does not test a near-copy/crop resolver,
assert authenticity, geolocate a scene, or validate fictional caption truth.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import platform
from PIL import Image, __version__ as PILLOW_VERSION
from generate_queries import ROOT,DATASET,read_catalog,strict_json_loads
from unpack_assets import confined_target,MAX_BYTES


def inspect_image(path):
    if path.stat().st_size>MAX_BYTES:raise ValueError('Image exceeds primary asset budget')
    payload=path.read_bytes()
    with Image.open(io.BytesIO(payload)) as image:image.verify()
    with Image.open(io.BytesIO(payload)) as image:
        image.load();exif=image.getexif();gps=exif.get_ifd(34853) if 34853 in exif else {}
        return {'sha256':hashlib.sha256(payload).hexdigest(),'byte_size':len(payload),
                'width_px':image.width,'height_px':image.height,'mime_type':Image.MIME[image.format],
                'format':image.format,'exif_present':bool(exif),'gps_present':bool(gps)}


def property_errors(record,actual):
    return [record['id']+': measured '+field+' differs from catalog' for field in
            ('sha256','byte_size','width_px','height_px','mime_type') if record[field]!=actual[field]]


def check_family_geometry(family,measured):
    errors=[]
    expected_operation={'base_plus_exact_copy':'byte_copy','base_plus_resize':'resize','base_plus_reencode':'reencode','base_plus_crop':'crop','singleton':None}
    family_class=family.get('family_class')
    if family_class not in expected_operation:
        errors.append(family['id']+': unknown family class')
    else:
        operations=Counter(member['operation'] for member in family['members'])
        expected=Counter({'base':1})
        if expected_operation[family_class]:expected[expected_operation[family_class]]=1
        if operations!=expected:errors.append(family['id']+': member operations differ from family class')
    base=measured.get(family['base_media_id'])
    if base is None:return [family['id']+': missing decoded base']
    for member in family['members']:
        actual=measured.get(member['media_id']);op=member['operation'];params=member['parameters']
        if actual is None:errors.append(member['media_id']+': missing decoded member');continue
        if op=='base':
            if member['media_id']!=family['base_media_id'] or member['parent_media_id'] is not None:errors.append(family['id']+': invalid base member')
            continue
        if member['parent_media_id']!=family['base_media_id']:errors.append(member['media_id']+': member must derive directly from base')
        same_hash=actual['sha256']==base['sha256']
        if op=='byte_copy':
            if not same_hash:errors.append(member['media_id']+': exact-copy bytes differ')
            continue
        if same_hash:errors.append(member['media_id']+': transformed bytes did not change')
        if op=='resize':expected=(params['width_px'],params['height_px'])
        elif op=='reencode':expected=(base['width_px'],base['height_px'])
        elif op=='crop':
            box=params['crop_box']
            if not isinstance(box,list) or len(box)!=4 or any(type(value) is not int for value in box):
                errors.append(member['media_id']+': invalid crop box');continue
            left,top,right,bottom=box
            if not (0<=left<right<=base['width_px'] and 0<=top<bottom<=base['height_px']):
                errors.append(member['media_id']+': crop box outside base');continue
            expected=(right-left,bottom-top)
        else:errors.append(member['media_id']+': unknown transformation');continue
        if (actual['width_px'],actual['height_px'])!=expected:errors.append(member['media_id']+': measured dimensions differ from transform recipe')
        if op in ('reencode','crop') and actual['format']!='JPEG':errors.append(member['media_id']+': expected JPEG derivative')
        if params['metadata_policy']=='strip' and actual['exif_present']:errors.append(member['media_id']+': EXIF remains despite strip policy')
    return errors


def reproduce_derivative(base_path,member):
    """Apply the committed dummy-asset recipe in memory; never save a media file.

Resize JPEG quality 86 and optimize=True are explicit defaults from
    generate_assets.py. Exact byte reproduction is Pillow/encoder-version specific.
    """
    operation=member['operation'];params=member['parameters']
    if operation not in ('resize','reencode','crop'):raise ValueError('Unsupported derivative recipe')
    with Image.open(base_path) as base:
        image=base.convert('RGB')
    if operation=='resize':
        image=image.resize((params['width_px'],params['height_px']),Image.Resampling.LANCZOS)
        quality=86
    else:
        quality=params['jpeg_quality']
        if operation=='crop':image=image.crop(tuple(params['crop_box']))
    if type(quality) is not int or not 1<=quality<=100:raise ValueError('Invalid JPEG recipe quality')
    output=io.BytesIO();image.save(output,format='JPEG',quality=quality,optimize=True)
    return output.getvalue()


def run_media_audit(root):
    root=root.resolve();data=root/'demo/datasets'/DATASET;fixtures=root/'tests/fixtures'/DATASET
    catalog=read_catalog(root);media=sorted((r for r in catalog.values() if r['kind']=='media'),key=lambda r:r['id'])
    quota=json.loads((root/'demo/spec/quotas.json').read_text())['images']
    families=[strict_json_loads(line) for line in (fixtures/'oracle/media-families.jsonl').read_text().splitlines()]
    inventory={item['path']:item for item in json.loads((data/'manifest.json').read_text())['assets']}
    checks=[]
    def add(rule,errors,observed,expected,limitations=()):
        checks.append({'rule_id':rule,'status':'fail' if errors else 'pass',
                       'observed':{'failure_count':len(errors),'examples':errors[:12],**observed},'expected':expected,
                       'evidence_paths':[f'demo/assets/{DATASET}',f'tests/fixtures/{DATASET}/oracle/media-families.jsonl'],
                       'limitations':list(limitations)})
    measured={};thumbs={};image_errors=[];thumb_errors=[]
    for row in media:
        try:
            actual=inspect_image(confined_target(root,row['asset_path']));measured[row['id']]=actual
            image_errors.extend(property_errors(row,actual))
            item=inventory[row['asset_path']]
            if item['sha256']!=actual['sha256'] or item['byte_size']!=actual['byte_size']:image_errors.append(row['id']+': manifest integrity differs from actual image')
        except (OSError,ValueError,KeyError,SyntaxError) as error:image_errors.append(row['id']+': '+str(error).replace(str(root),'<repo>'))
        try:
            actual=inspect_image(confined_target(root,row['thumbnail_path']));thumbs[row['id']]=actual
            if max(actual['width_px'],actual['height_px'])!=quota['thumbnail_long_edge_pixels']:thumb_errors.append(row['id']+': thumbnail long edge mismatch')
            item=inventory[row['thumbnail_path']]
            if item['sha256']!=actual['sha256'] or item['byte_size']!=actual['byte_size']:thumb_errors.append(row['id']+': thumbnail integrity mismatch')
        except (OSError,ValueError,KeyError,SyntaxError) as error:thumb_errors.append(row['id']+': '+str(error).replace(str(root),'<repo>'))
    if len(measured)!=quota['uploads']:image_errors.append('Decoded upload count differs from quota')
    if len(thumbs)!=quota['uploads']:thumb_errors.append('Decoded thumbnail count differs from upload quota')
    add('decoded_image_properties',image_errors,{'decoded':len(measured)},'200 actual decoded images match catalog/manifest hash, bytes, dimensions and MIME')
    checks[-1]['observed']['manifest_sha256']=hashlib.sha256((data/'manifest.json').read_bytes()).hexdigest()
    checks[-1]['evidence_paths'].extend([f'demo/datasets/{DATASET}/records/media',f'demo/datasets/{DATASET}/manifest.json'])
    add('decoded_thumbnails',thumb_errors,{'decoded':len(thumbs)},'200 decoded thumbnails, measured hashes and 320-pixel long edge')
    distinct=len({item['sha256'] for item in measured.values()})
    add('distinct_image_hashes',[] if distinct==quota['unique_sha256'] else ['Distinct hash quota mismatch'],{'unique_sha256':distinct},quota['unique_sha256'])
    family_errors=[];members=[m['media_id'] for family in families for m in family['members']]
    counts=dict(Counter(f['family_class'] for f in families))
    if counts!=quota['family_classes'] or len(families)!=quota['base_families']:family_errors.append('Family class/count quota mismatch')
    if len(members)!=len(set(members)) or set(members)!={m['id'] for m in media}:family_errors.append('Families must partition all uploads exactly once')
    for family in families:family_errors.extend(check_family_geometry(family,measured))
    add('family_structure_and_transform_geometry',family_errors,{'families':len(families),'classes':counts},quota['family_classes'],
        ['Verifies exact-copy hashes, changed derivative bytes, dimensions/crop bounds and metadata policy. Does not prove crop/resize pixel content or evaluate an application near-copy matcher.'])
    reproduction_errors=[];reproduced=Counter()
    for family in families:
        base=catalog[family['base_media_id']]
        for member in family['members']:
            if member['operation'] not in ('resize','reencode','crop'):continue
            try:
                payload=reproduce_derivative(confined_target(root,base['asset_path']),member)
                if hashlib.sha256(payload).hexdigest()!=measured[member['media_id']]['sha256']:
                    reproduction_errors.append(member['media_id']+': current generator recipe/encoder does not reproduce stored bytes')
                else:reproduced[member['operation']]+=1
            except (OSError,ValueError,KeyError,TypeError,SyntaxError) as error:
                reproduction_errors.append(member['media_id']+': '+str(error).replace(str(root),'<repo>'))
    add('generator_derivative_byte_reproduction',reproduction_errors,
        {'bit_exact_derivatives':sum(reproduced.values()),'operations':dict(reproduced),'resize_jpeg_quality':86,'jpeg_optimize':True},
        '40 derived files reproduce byte-for-byte from their base with the committed generator recipe',
        ['In-memory generation-recipe check tied to recorded Pillow/encoder versions, not a general near-copy/crop detector or application evidence signal. No asset file is written.'])
    checks[-1]['evidence_paths'].append('tools/test_data/generate_assets.py')
    metadata=Counter();metadata_errors=[];base_size_errors=[]
    for family in families:
        actual=measured.get(family['base_media_id'])
        if actual is None:metadata_errors.append(family['id']+': base unavailable');continue
        mode='controlled_gps_exif' if actual['gps_present'] else 'non_gps_exif' if actual['exif_present'] else 'no_exif';metadata[mode]+=1
        if mode!=family['base_metadata']:metadata_errors.append(family['id']+': measured EXIF class differs')
        if not 1280<=max(actual['width_px'],actual['height_px'])<=1920:base_size_errors.append(family['id']+': base long edge outside 1280..1920')
    if dict(metadata)!=quota['base_metadata']:metadata_errors.append('Measured base EXIF coverage differs from quota')
    add('base_exif_coverage',metadata_errors,{'classes':dict(metadata)},quota['base_metadata'],['EXIF/GPS presence is controlled metadata, not verified location, capture time or authenticity.'])
    add('base_image_dimensions',base_size_errors,{'bases_checked':sum(metadata.values())},'120 bases with 1280..1920-pixel long edge')
    family_by_id={f['id']:f for f in families};lookalike_errors=[];lookalike_pairs=set()
    for family in families:
        for ident in family['unrelated_lookalike_family_ids']:
            other=family_by_id.get(ident)
            if other is None or family['id']==ident or family['family_class']!='singleton' or other['family_class']!='singleton' or family['id'] not in other['unrelated_lookalike_family_ids']:
                lookalike_errors.append(family['id']+': invalid/nonreciprocal singleton negative pair')
            lookalike_pairs.add(tuple(sorted((family['id'],ident))))
    if len(lookalike_pairs)!=quota['unrelated_lookalike_pairs_among_singletons']:lookalike_errors.append('Singleton negative-pair count mismatch')
    add('lookalike_oracle_links',lookalike_errors,{'pairs':len(lookalike_pairs)},10,['Checks held-out pair topology only, not visual similarity or an identity/face model.'])
    late_errors=[];late_count=0
    def when(value):return datetime.fromisoformat(value.replace('Z','+00:00'))
    for family in families:
        if 'earliest_publication_ingested_last' not in family['tags']:continue
        late_count+=1;base=catalog[family['base_media_id']]
        children=[catalog[m['media_id']] for m in family['members'] if m['parent_media_id']]
        for child in children:
            old_source=catalog[base['source_id']];new_source=catalog[child['source_id']]
            try:
                if not (when(base['available_at'])>when(child['available_at']) and when(old_source['published_at']['value'])<when(new_source['published_at']['value'])):
                    late_errors.append(family['id']+': late-ingestion chronology mismatch')
            except (ValueError,TypeError,AttributeError):late_errors.append(family['id']+': unknown/unparseable publication time')
        if not children:late_errors.append(family['id']+': missing later published comparison copy')
    if late_count<quota['earliest_publication_ingested_last_families_minimum']:late_errors.append('Too few late-ingestion families')
    add('earlier_publication_arrives_later',late_errors,{'families':late_count},'At least five earlier publications become available after their later copies', ['Catalog chronology only; runtime ingestion has not been executed.'])
    total=sum(m['byte_size'] for m in measured.values())+sum(m['byte_size'] for m in thumbs.values())
    add('primary_asset_budget',[] if total<=quota['asset_budget_mib']*1024*1024 else ['Primary asset budget exceeded'],{'actual_bytes':total},quota['asset_budget_mib']*1024*1024)
    checks.append({'rule_id':'application_media_evidence','status':'blocked','observed':'No application EvidenceWalker or near-copy/crop detection was executed.',
                   'expected':'Actual runtime checks with tool/version/input hashes/results before claiming application verification',
                   'evidence_paths':[],'limitations':['Caption/GPS conflict semantics, human visual review and scene authenticity are not established by these file checks.']})
    totals=Counter(c['status'] for c in checks)
    return {'dataset_id':DATASET,'generated_at':datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'tools':[{'name':'tools/test_data/audit_media.py','version':'1.1'},{'name':'Pillow','version':PILLOW_VERSION},{'name':'Python','version':platform.python_version()}],
            'checks':checks,'summary':{key:totals[key] for key in ('pass','fail','blocked')}}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--output',type=Path)
    args=parser.parse_args();report=run_media_audit(args.root)
    if args.output:args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report['summary']))
    else:print(json.dumps(report,ensure_ascii=False,indent=2))
    raise SystemExit(1 if report['summary']['fail'] else 2 if report['summary']['blocked'] else 0)
