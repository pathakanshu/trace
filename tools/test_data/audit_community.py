"""Cross-record community fixture invariants; never executes votes/tasks/alerts."""
from collections import Counter, defaultdict
from audit_contracts import utc


def community_errors(records, hero_person_ids):
    catalog={r['id']:r for r in records}
    votes=[r for r in records if r['kind']=='vote']
    voting=[]
    pairs=Counter((r['contributor_id'],r['contribution_id']) for r in votes)
    for pair,count in sorted(pairs.items()):
        if count>1:voting.append(f'{pair[0]} -> {pair[1]}: {count} votes for the same pair')
    for vote in votes:
        contribution=catalog.get(vote['contribution_id'])
        if contribution and contribution['contributor_id']==vote['contributor_id']:
            voting.append(vote['id']+': contributor votes on their own contribution')
    workflow=[]
    for task in [r for r in records if r['kind']=='task']:
        if task['state'] in ('SUBMITTED','REVIEWED') and (not task['assignee_id'] or not task['submission_contribution_ids']):
            workflow.append(task['id']+': submitted/reviewed task lacks assignee or contributions')
        if task['state']=='OPEN' and (task['assignee_id'] or task['submission_contribution_ids'] or task['review']):
            workflow.append(task['id']+': open task contains assignment/submission/review')
        if task['state']=='IN_PROGRESS' and not task['assignee_id']:
            workflow.append(task['id']+': in-progress task lacks assignee')
        review=task['review']
        if task['state']=='REVIEWED' and (not review or not review['evidence_claim_ids']):
            workflow.append(task['id']+': reviewed task lacks cited review evidence')
        if review and utc(review['reviewed_at'])>utc(task['available_at']):
            workflow.append(task['id']+': review follows task release')
        for ident in task['submission_contribution_ids']:
            contribution=catalog.get(ident)
            if not contribution:workflow.append(task['id']+': missing submission '+ident);continue
            if contribution['target']!=task['target']:
                workflow.append(task['id']+': submission target differs: '+ident)
            if review and utc(review['reviewed_at'])<utc(contribution['submitted_at']):
                workflow.append(task['id']+': review precedes submitted contribution '+ident)
    following=[];sub_keys=Counter();followers=defaultdict(set);kinds_by_actor=defaultdict(set)
    for sub in [r for r in records if r['kind']=='subscription']:
        key=(sub['contributor_id'],sub['subject']['kind'],sub['subject']['id']);sub_keys[key]+=1
        if sub['active']:
            followers[(sub['subject']['kind'],sub['subject']['id'])].add(sub['contributor_id'])
            kinds_by_actor[sub['contributor_id']].add(sub['subject']['kind'])
        if sub['delivery']!='in_app':following.append(sub['id']+': subscription delivery is not in-app')
    following.extend(f'{actor}/{kind}/{ident}: duplicate subscription' for (actor,kind,ident),count in sorted(sub_keys.items()) if count>1)
    if not any(len(followers[('person',pid)])>=2 for pid in hero_person_ids):
        following.append('No hero Person has two distinct active followers')
    people=[r['id'] for r in records if r['kind']=='person']
    if not any(not followers[('person',pid)] for pid in people):following.append('No Person without followers exists')
    if not any(kind=='location' and actors for (kind,_),actors in followers.items()):following.append('No active location follower exists')
    if not any(len(kinds)>=2 for kinds in kinds_by_actor.values()):following.append('No contributor follows multiple subject kinds')
    observed={'votes':len(votes),'self_votes':sum('own contribution' in e for e in voting),
              'duplicate_vote_pairs':sum(count>1 for count in pairs.values()),
              'extra_votes_on_duplicate_pairs':sum(count-1 for count in pairs.values()),
              'task_submission_target_mismatches':sum('target differs' in e for e in workflow),
              'max_distinct_hero_followers':max((len(followers[('person',pid)]) for pid in hero_person_ids),default=0)}
    return {'community_vote_rules':sorted(voting),'task_submission_and_review':sorted(workflow),'subscription_coverage_and_uniqueness':sorted(following)},observed
