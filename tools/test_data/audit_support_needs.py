"""Declared support-request citation coverage, not medical or identity inference."""
from audit_contracts import utc


def support_need_errors(records, minimum=30):
    catalog={row['id']:row for row in records};errors=[];declared=0;valid=0
    for person in records:
        if person['kind']!='person' or not person['support_needs_claim_ids']:continue
        declared+=1;before=len(errors);ids=person['support_needs_claim_ids']
        if len(ids)!=len(set(ids)):errors.append(person['id']+': duplicate support citation')
        for ident in ids:
            claim=catalog.get(ident)
            if not claim or claim['kind']!='claim':
                errors.append(person['id']+': missing or wrong-kind support claim');continue
            source=catalog.get(claim['source_id'])
            if claim['subject']!={'kind':'person','id':person['id']}:
                errors.append(person['id']+': support claim concerns another subject')
            if claim['incident_id']!=person['incident_id'] or not source or source['kind']!='source' or source['incident_id']!=person['incident_id']:
                errors.append(person['id']+': missing or cross-incident attribution')
            text=claim['assertion']['text'];excerpt=claim['provenance']['original_excerpt']
            if not text.strip() or text not in excerpt:
                errors.append(person['id']+': support assertion lacks preserved original excerpt')
            if utc(claim['available_at'])>utc(person['available_at']):
                errors.append(person['id']+': support claim is unavailable at Person release')
        valid+=len(errors)==before
    if valid<minimum:errors.append(f'Only {valid} Person records have valid declared support-request citations; need at least {minimum}')
    return errors,{'person_records_declaring_support_requests':declared,
                   'person_records_with_valid_support_citations':valid,'minimum_person_records':minimum}
