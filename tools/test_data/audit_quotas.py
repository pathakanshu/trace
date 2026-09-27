"""Recompute catalog coverage directly from rows, never cached validation results.

Counts establish fixture coverage only, not truth, source independence, geographic
suitability, media verification or successful application execution.
"""
from collections import Counter,defaultdict


def quota_errors(records,quota):
    by_kind=defaultdict(list)
    for row in records:by_kind[row['kind']].append(row)
    dimensions=[];errors=[]
    def check(name,actual,expected,mode='exact'):
        passed=actual==expected if mode=='exact' else actual>=expected
        dimensions.append({'rule':name,'actual':actual,'expected':expected,'comparison':mode,'passed':passed})
        if not passed:errors.append(name+': measured coverage differs from quota')
    def counts(kind,field):return dict(Counter(row[field] for row in by_kind[kind]))
    check('primary_catalog_counts',dict(Counter(row['kind'] for row in records)),quota['primary_catalog_counts'])
    for kind,field,key in (
        ('organization','organization_type','organizations_by_type'),
        ('facility','facility_type','facilities_by_type'),
        ('infrastructure','infrastructure_type','infrastructure_by_type'),
        ('hazard','hazard_type','hazards_by_type'),('aid','aid_type','aid_by_type'),
        ('investigation','investigation_type','investigations_by_topic')):
        check(key,counts(kind,field),quota[key])
    for kind,field,key in (
        ('contribution','contribution_type','contribution_types'),('vote','value','vote_values'),
        ('task','task_type','task_types'),('task','state','task_states')):
        check('community.'+key,counts(kind,field),quota['community'][key])
    check('subscriptions_by_subject_kind',dict(Counter(row['subject']['kind'] for row in by_kind['subscription'])),quota['subscriptions_by_subject_kind'])
    sources=by_kind['source'];claims=by_kind['claim'];sq=quota['sources']
    check('sources.publisher_type_counts',dict(Counter(row['publisher']['kind'] for row in sources)),sq['publisher_type_counts'])
    check('sources.format_counts',counts('source','raw_format'),sq['format_counts'])
    per_source=Counter(row['source_id'] for row in claims)
    check('sources.claim_cardinality_histogram',dict(Counter(str(per_source[row['id']]) for row in sources)),sq['claim_cardinality_histogram'])
    dependent=sum(bool(row['dependencies']) for row in sources)
    check('sources.authored_independent',len(sources)-dependent,sq['authored_independent'])
    check('sources.declared_dependent',dependent,sq['declared_dependent'])
    reports=Counter(row['publisher']['id'] for row in sources if row['publisher']['kind']=='organization')
    check('sources.minimum_reports_per_organization',min((reports[row['id']] for row in by_kind['organization']),default=0),sq['minimum_reports_per_organization'],'minimum')
    check('claims_by_subject_kind',dict(Counter(row['subject']['kind'] for row in claims)),quota['claims_by_subject_kind'])
    check('person_claims_by_type',dict(Counter(row['assertion']['type'] for row in claims if row['subject']['kind']=='person')),quota['person_claims_by_type'])
    check('community.anonymous_display_contributions',sum(row['public_display']=='anonymous' for row in by_kind['contribution']),quota['community']['anonymous_display_contributions'])
    check('community.nepali_with_english_rendering_minimum',sum(row['language']=='ne' and bool(row['english_rendering'] and row['english_rendering'].strip()) for row in by_kind['contribution']),quota['community']['nepali_with_english_rendering_minimum'],'minimum')
    media_counts=Counter(len(set(row['supporting_media_ids'])) for row in claims)
    referenced_media={ident for row in claims for ident in row['supporting_media_ids']}
    for name,value in (
        ('uploads_cited_by_claim_minimum',len(referenced_media)),
        ('claims_citing_two_or_more_uploads_minimum',sum(count for length,count in media_counts.items() if length>=2)),
        ('claims_citing_exactly_one_upload_minimum',media_counts[1])):
        check('images.'+name,value,quota['images'][name],'minimum')
    return errors,dimensions
