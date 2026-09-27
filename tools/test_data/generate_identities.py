#!/usr/bin/env python3
"""Normalize held-out identity labels to the existing support contract.

Preserves allocated private group IDs, membership and canonical age. Initial
location is taken only from existing initial reports. Unknown geography remains
unknown; no new coordinates, public identity links or runtime decisions are made.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
import re
from pathlib import Path
from generate_queries import ROOT, DATASET, read_catalog, write_fixture_jsonl

FIELDS=set('id person_ids canonical_age primary_person_id initial_location_id initial_precision initial_cluster'.split())
CLUSTERS={'Kodari':'kodari_tatopani','Tatopani':'kodari_tatopani','Bahrabise':'bahrabise','Khadichaur':'lamosanghu_khadichaur'}


def build_identities(catalog,plan,geography):
    features={feature['id']:feature for feature in geography['features']}
    rows=[]
    for group in sorted(plan['identity_groups'],key=lambda g:g['identity_id']):
        primary=group['primary_person_id'];members=group['person_ids']
        if primary not in members:raise ValueError('Primary record is outside its private identity')
        claims=[catalog[ident] for ident in group['initial_claim_ids']]
        if Counter(c['subject']['id'] for c in claims)!=Counter(members):raise ValueError('Initial claims must cover each identity member once')
        if any(c['kind']!='claim' or c['subject']['kind']!='person' or c['assertion']['type']!='MISSING' for c in claims):raise ValueError('Initial identity claims must be person MISSING reports')
        primary_claim=next(c for c in claims if c['subject']['id']==primary)
        location_id=primary_claim['location_id'];precision='unknown';cluster=None
        if location_id is not None:
            location=catalog[location_id]
            if location['kind']!='location':raise ValueError('Initial location reference has wrong kind')
            geometry=location['geometry']
            if geometry['type']=='Point':
                precision='point'
                context_ids=location['coordinate_provenance']['context_feature_ids']
                choices={CLUSTERS.get(features[ident]['properties']['label']) for ident in context_ids}
                if len(choices)!=1 or None in choices:raise ValueError('Initial point lacks an unambiguous supported geographic cluster')
                cluster=next(iter(choices))
            elif geometry['type'] in ('Polygon','MultiPolygon'):precision='area'
            else:raise ValueError('Unsupported initial location geometry')
        rows.append({'id':group['identity_id'],'person_ids':list(members),'canonical_age':group['canonical_age'],
                     'primary_person_id':primary,'initial_location_id':location_id,
                     'initial_precision':precision,'initial_cluster':cluster})
    return rows


def validate_identities(rows,catalog,plan,geography,quota):
    if len(rows)!=quota['distinct_individuals']:raise ValueError('Private identity count differs from quota')
    if len({row['id'] for row in rows})!=len(rows):raise ValueError('Private identity IDs repeat')
    people={row['id'] for row in catalog.values() if row['kind']=='person'}
    members=[ident for row in rows for ident in row['person_ids']]
    if len(members)!=len(set(members)) or set(members)!=people:raise ValueError('Identity groups must partition all Person records once')
    if {str(k):v for k,v in Counter(len(row['person_ids']) for row in rows).items()}!=quota['record_multiplicity']:raise ValueError('Identity multiplicity differs from quota')
    ages=Counter()
    for row in rows:
        if set(row)!=FIELDS or not re.fullmatch(r'gid-\d{6}',row['id']):raise ValueError('Identity shape/ID differs from contract')
        age=row['canonical_age']
        if age is not None and (type(age) is not int or not 0<=age<=90):raise ValueError('Canonical age must be null or integer 0..90')
        ages['unknown' if age is None else '0_to_17' if age<=17 else '18_to_59' if age<=59 else '60_to_90']+=1
    if dict(ages)!=quota['age_bands']:raise ValueError('Private age bands differ from quota')
    if rows!=build_identities(catalog,plan,geography):raise ValueError('Identity oracle differs from allocation or actual initial-report locations')


def write_identities(root):
    root=root.resolve();fixtures=root/'tests/fixtures'/DATASET
    catalog=read_catalog(root);plan=json.loads((fixtures/'allocation-plan.json').read_text())
    geography=json.loads((root/'demo/datasets'/DATASET/'context/geography.geojson').read_text())
    quota=json.loads((root/'demo/spec/quotas.json').read_text())['identity_oracle']
    rows=build_identities(catalog,plan,geography);validate_identities(rows,catalog,plan,geography,quota)
    write_fixture_jsonl(root,'oracle/identities.jsonl',rows)
    return {'identities':len(rows),'precision_counts':dict(Counter(row['initial_precision'] for row in rows)),
            'public_records_changed':0,'runtime_identity_decisions':0}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT)
    print(json.dumps(write_identities(parser.parse_args().root)))
