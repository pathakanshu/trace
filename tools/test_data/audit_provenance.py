"""Static publication and correction invariants; never executes ingestion.

Acyclic dependencies describe declared lineage. They do not establish source
independence, truth, successful deduplication or an executed correction workflow.
"""
from collections import Counter,deque


def dag_errors(nodes,edges,label):
    nodes=set(nodes);edges=list(edges);errors=[]
    repeats=[edge for edge,count in Counter(edges).items() if count>1]
    errors.extend(label+': duplicate edge '+a+' -> '+b for a,b in repeats)
    incoming={ident:0 for ident in nodes};outgoing={ident:[] for ident in nodes}
    for a,b in sorted(set(edges)):
        if a not in nodes or b not in nodes:
            errors.append(label+': missing endpoint '+a+' -> '+b);continue
        if a==b:errors.append(label+': self-reference '+a)
        incoming[b]+=1;outgoing[a].append(b)
    ready=deque(sorted(ident for ident,count in incoming.items() if count==0));visited=0
    while ready:
        ident=ready.popleft();visited+=1
        for target in outgoing[ident]:
            incoming[target]-=1
            if incoming[target]==0:ready.append(target)
    blocked=sorted(ident for ident,count in incoming.items() if count>0)
    if blocked:errors.append(label+': cycle prevents topological ordering: '+', '.join(blocked[:12]))
    return errors


def provenance_errors(records):
    catalog={row['id']:row for row in records}
    sources=[row for row in records if row['kind']=='source'];claims=[row for row in records if row['kind']=='claim']
    errors=[];scopes={};dependencies=[];corrections=[]
    for source in sources:
        ident=source['id'];publisher=source['publisher'];pub=catalog.get(publisher['id'])
        scope=(source['incident_id'],publisher['kind'],publisher['id'],source['report_reference'])
        if scope in scopes:errors.append(ident+': publication reference duplicates '+scopes[scope]+' within its publisher/incident scope')
        else:scopes[scope]=ident
        if pub is None or pub['kind']!=publisher['kind']:
            errors.append(ident+': missing or wrong-kind publisher')
        elif publisher['kind']=='organization':
            if source['source_type']!=pub['organization_type']:errors.append(ident+': source_type differs from publisher organization_type')
        elif publisher['kind']=='contributor':
            if source['source_type'] not in ('INDIVIDUAL','COMMUNITY_NEWS'):errors.append(ident+': contributor publication has institutional source_type')
        else:errors.append(ident+': unsupported publisher kind')
        edges=source['dependencies'];disclosure=source['dependency_disclosure']
        if disclosure=='declared':
            if not edges:errors.append(ident+': declared dependency has no source reference')
        elif disclosure in ('no_dependency_declared','unknown'):
            if edges:errors.append(ident+': dependencies contradict disclosure')
        else:errors.append(ident+': unknown dependency disclosure')
        dependencies.extend((ident,edge['source_id']) for edge in edges)
    for claim in claims:corrections.extend((claim['id'],target) for target in claim['corrects_claim_ids'])
    errors.extend(dag_errors([row['id'] for row in sources],dependencies,'source lineage'))
    errors.extend(dag_errors([row['id'] for row in claims],corrections,'claim corrections'))
    return errors,{'sources_checked':len(sources),'unique_publication_scopes':len(scopes),
                   'declared_dependency_edges':len(dependencies),'claim_correction_edges':len(corrections)}
