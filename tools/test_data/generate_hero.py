#!/usr/bin/env python3
"""Select a reference-closed private hero profile from unchanged catalog records.

This exports inputs only. Scenario IDs are planned coverage, not executed stories.
No primary records, source documents, assets, identities or runtime results change.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from audit_contracts import read_jsonl, references, reference_errors
from generate_queries import ROOT, DATASET, read_catalog


def select_hero(records, plan):
    catalog={r['id']:r for r in records}
    if len(catalog)!=len(records):raise ValueError('Duplicate primary catalog ID')
    by_source,by_person,person_subscriptions=defaultdict(list),defaultdict(list),defaultdict(list)
    for row in records:
        if row['kind']=='claim':
            by_source[row['source_id']].append(row['id'])
            if row['subject']['kind']=='person':by_person[row['subject']['id']].append(row['id'])
        elif row['kind']=='subscription' and row['subject']['kind']=='person':
            person_subscriptions[row['subject']['id']].append(row['id'])
    pending=set(plan['hero_person_ids']) | set(plan['hero_media_ids'])
    pending.update(r['id'] for r in records if r['kind']=='organization')
    pending.update(ident for story in plan['story_plans'] for ident in story['focal_ids'])
    selected=set()
    while pending:
        ident=min(pending);pending.remove(ident)
        if ident in selected:continue
        row=catalog.get(ident)
        if row is None:raise ValueError('Hero dependency missing from primary catalog: '+ident)
        selected.add(ident)
        pending.update(target for _,target in references(row) if target not in selected)
        if row['kind']=='person':
            pending.update((set(by_person[ident]) | set(person_subscriptions[ident]))-selected)
        if row['kind']=='source':pending.update(set(by_source[ident])-selected)
    return sorted((catalog[ident] for ident in selected),key=lambda r:(r['kind'],r['id']))


def hero_errors(rows, full_records, plan, manifest, groups, families, quotas):
    errors=[];catalog={r['id']:r for r in full_records};selected={r['id']:r for r in rows}
    if len(selected)!=len(rows):errors.append('Hero IDs repeat')
    for ident,row in selected.items():
        if catalog.get(ident)!=row:errors.append(ident+': hero record differs from primary catalog')
    expected={r['id'] for r in select_hero(full_records,plan)}
    if set(selected)!=expected:errors.append('Hero selection differs from full required reference closure')
    missing,cross,future=reference_errors(rows)
    errors.extend(missing+cross+future)
    hero_people={r['id'] for r in rows if r['kind']=='person'}
    selected_groups=[g for g in groups if set(g['person_ids']) & hero_people]
    if any(not set(g['person_ids']) <= hero_people for g in selected_groups):errors.append('Hero includes a partial identity group')
    quota=quotas['hero_profile']
    multiplicity={str(k):v for k,v in Counter(len(g['person_ids']) for g in selected_groups).items()}
    if len(selected_groups)!=quota['individuals'] or multiplicity!=quota['record_multiplicity']:errors.append('Hero identity/multiplicity quota mismatch')
    if len(hero_people)!=quota['person_records']:errors.append('Hero Person count mismatch')
    media={r['id'] for r in rows if r['kind']=='media'}
    if len(media)<quota['minimum_image_uploads']:errors.append('Too few hero media uploads')
    family_by_media={member['media_id']:family for family in families for member in family['members']}
    classes={family_by_media[mid]['family_class'] for mid in media if mid in family_by_media}
    expected_classes={'base_plus_crop','base_plus_exact_copy','base_plus_reencode','base_plus_resize','singleton'}
    if classes!=expected_classes:errors.append('Hero does not cover all five image family classes')
    actual=Counter(r['kind'] for r in rows)
    for kind in quotas['primary_catalog_counts']:
        if manifest['record_counts_from_foreign_key_closure'].get(kind)!=actual[kind]:errors.append('Manifest count mismatch: '+kind)
    group_ids=sorted(g.get('id',g.get('identity_id')) for g in selected_groups)
    if manifest['identity_group_ids']!=group_ids or manifest['identity_group_count']!=len(group_ids):errors.append('Manifest private identity selection mismatch')
    if manifest['person_record_ids']!=sorted(hero_people):errors.append('Manifest Person selection mismatch')
    if manifest['image_upload_ids']!=sorted(plan['hero_media_ids']):errors.append('Manifest media seeds mismatch')
    if manifest['scenario_ids']!=[story['id'] for story in plan['story_plans']]:errors.append('Manifest scenario plans mismatch')
    return errors


def load_inputs(root):
    fixtures=root/'tests/fixtures'/DATASET
    return (list(read_catalog(root).values()),json.loads((fixtures/'allocation-plan.json').read_text()),
            read_jsonl(fixtures/'oracle/identities.jsonl'),read_jsonl(fixtures/'oracle/media-families.jsonl'),
            json.loads((root/'demo/spec/quotas.json').read_text()))


def write_hero(root):
    root=root.resolve();records,plan,groups,families,quotas=load_inputs(root)
    rows=select_hero(records,plan);people={r['id'] for r in rows if r['kind']=='person'}
    selected_groups=[g for g in groups if set(g['person_ids']) & people]
    families_by_media={m['media_id']:f for f in families for m in f['members']}
    counts=Counter(r['kind'] for r in rows)
    manifest={'dataset_id':DATASET,'profile':'hero-50','private_fixture':True,
              'identity_group_count':len(selected_groups),'person_record_ids':sorted(people),
              'identity_group_ids':sorted(g.get('id',g.get('identity_id')) for g in selected_groups),
              'image_upload_ids':sorted(plan['hero_media_ids']),
              'image_family_classes':sorted({families_by_media[mid]['family_class'] for mid in plan['hero_media_ids']}),
              'scenario_ids':[story['id'] for story in plan['story_plans']],
              'record_counts_from_foreign_key_closure':{kind:counts[kind] for kind in sorted(quotas['primary_catalog_counts'])},
              'primary_records_must_not_import_oracle_fields':True}
    errors=hero_errors(rows,records,plan,manifest,groups,families,quotas)
    if errors:raise ValueError('; '.join(errors[:12]))
    destination=root/'tests/fixtures'/DATASET/'hero'
    if not destination.resolve().is_relative_to(root/'tests/fixtures'/DATASET):raise ValueError('Hero directory escapes fixture root')
    outputs={destination/'manifest.json':json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'}
    for kind in sorted(counts):
        outputs[destination/(kind+'.jsonl')]=''.join(json.dumps(r,ensure_ascii=False,separators=(',',':'))+'\n' for r in rows if r['kind']==kind)
    for path in destination.glob('*.jsonl'):
        if path not in outputs:raise ValueError('Unexpected old hero file requires explicit review: '+path.name)
    for path in outputs:
        if not path.resolve().is_relative_to(destination):raise ValueError('Hero file escapes fixture root')
    for path,text in outputs.items():
        path.parent.mkdir(parents=True,exist_ok=True)
        if not path.exists() or path.read_text(encoding='utf-8')!=text:path.write_text(text,encoding='utf-8')
    return {'records':len(rows),'counts':dict(sorted(counts.items())),'runtime_executed':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT)
    print(json.dumps(write_hero(parser.parse_args().root)))
