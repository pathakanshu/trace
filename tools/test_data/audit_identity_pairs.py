"""Audit private identity benchmark labels and missing distinguishing context.

This checks fixture design only. It never merges/rejects an application candidate.
Identical supplied context is detectable; differing context does not prove a pair
is distinguishable or authorize an automatic identity decision.
"""
from collections import Counter
from itertools import combinations
import json
import re
import unicodedata


def normalized_name(text):
    return ' '.join(unicodedata.normalize('NFKC',text).casefold().split())


def context_fingerprint(person_id,pair,catalog):
    person=catalog[person_id]
    claims=[]
    for ident in pair['evidence_claim_ids']:
        claim=catalog[ident]
        if claim['subject']!={'kind':'person','id':person_id}:continue
        location=catalog.get(claim['location_id']) if claim['location_id'] else None
        # Distinct source/record/location IDs alone are not identity-disambiguating
        # facts. Compare supplied assertions, observation times and actual geometry.
        claims.append({'assertion':claim['assertion'],'reported_at':claim['reported_at'],
            'location':{key:location[key] for key in ('geometry','precision','uncertainty_radius_m')} if location else None})
    return {'description':person['description'],
            'claims':sorted(claims,key=lambda row:json.dumps(row,sort_keys=True))}


def audit_pairs(pairs,groups,catalog,quota):
    labels,indistinguishable=[],[]
    membership={person:group['id'] for group in groups for person in group['person_ids']}
    expected_positive={tuple(sorted(pair)) for group in groups for pair in combinations(group['person_ids'],2)}
    keys=[];positive=set();counts=Counter();same_name_age=0
    ids=[pair['id'] for pair in pairs]
    if len(ids)!=len(set(ids)):labels.append('Benchmark pair IDs repeat')
    for pair in pairs:
        ident=pair['id'];a,b=pair['person_a_id'],pair['person_b_id'];key=tuple(sorted((a,b)));keys.append(key)
        if not re.fullmatch(r'pair-\d{6}',ident):labels.append(ident+': invalid pair ID')
        if a==b:labels.append(ident+': self-pair is not a benchmark pair')
        if a not in membership or b not in membership:
            labels.append(ident+': missing Person/private membership');continue
        if type(pair['same_individual']) is not bool:
            labels.append(ident+': label is not a boolean');continue
        actual=membership[a]==membership[b];counts[pair['same_individual']]+=1
        if pair['same_individual']!=actual:labels.append(ident+': label disagrees with private membership')
        if pair['same_individual']:positive.add(key)
        claims=[catalog.get(cid) for cid in pair['evidence_claim_ids']]
        if not claims or any(not claim or claim['kind']!='claim' for claim in claims):
            labels.append(ident+': missing or wrong-kind cited claim');continue
        supported={claim['subject']['id'] for claim in claims if claim['subject']['kind']=='person'}
        if not {a,b}<=supported:labels.append(ident+': citations omit one or both candidate records')
        pa,pb=catalog[a],catalog[b]
        names_equal=normalized_name(pa['display_name'])==normalized_name(pb['display_name'])
        ages_equal=pa['reported_age'] is not None and pa['reported_age']==pb['reported_age']
        if not pair['same_individual'] and names_equal and ages_equal:
            same_name_age+=1
            if context_fingerprint(a,pair,catalog)==context_fingerprint(b,pair,catalog):
                indistinguishable.append(ident+': same name/age and indistinguishable supplied description, assertions, observation times and geometry')
    if len(keys)!=len(set(keys)):labels.append('Unordered candidate pairs repeat')
    if positive!=expected_positive:labels.append('Positive pairs do not enumerate every within-identity combination')
    if counts[True]!=quota['same_individual_pair_benchmarks'] or counts[False]!=quota['different_individual_pair_benchmarks']:
        labels.append('Positive/negative benchmark counts differ from quotas')
    if same_name_age<quota['hard_negative_pairs_sharing_name_and_age_minimum']:
        labels.append('Too few distinct-identity pairs sharing a known name and age')
    observed={'pairs':len(pairs),'positive':counts[True],'negative':counts[False],
              'same_name_and_age_negatives':same_name_age,'indistinguishable_cited_context':len(indistinguishable)}
    return labels,indistinguishable,observed
