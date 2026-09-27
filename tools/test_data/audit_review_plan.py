"""Private review-plan structure only; never executes or records identity decisions."""
from collections import Counter


def review_plan_errors(actions,groups,quotas):
    membership={pid:group['id'] for group in groups for pid in group['person_ids']}
    parent={pid:pid for pid in membership}
    def find(pid):
        while parent[pid]!=pid:
            parent[pid]=parent[parent[pid]];pid=parent[pid]
        return pid
    errors=[];counts=Counter();joins=0;cycles=[];legacy=0
    for action in actions:
        if action.get('operation')=='review_identity':
            ident=action['id'];payload=action['payload'];a,b=payload['person_a_id'],payload['person_b_id'];decision=payload['decision']
        elif action.get('action')=='human_review_required':
            # Legacy shape is still a separate contract failure. Reading it here
            # exposes the plan's graph defect without claiming an executable API.
            legacy+=1;ident=action['action_id'];a,b=action['person_a_id'],action['person_b_id']
            decision={'confirm_same_individual':'confirm','reject_match':'reject'}.get(action['expected_decision'],'unsupported')
        else:continue
        counts[decision]+=1
        if a not in membership or b not in membership or a==b:
            errors.append(ident+': invalid/missing pair');continue
        if decision=='confirm':
            if membership[a]!=membership[b]:errors.append(ident+': confirmation conflicts with private benchmark');continue
            left,right=find(a),find(b)
            if left==right:
                cycles.append(ident);errors.append(ident+': redundant confirmation creates a cycle')
            else:parent[right]=left;joins+=1
        elif decision=='reject':
            if membership[a]==membership[b]:errors.append(ident+': rejection conflicts with private benchmark')
        else:errors.append(ident+': unknown review decision')
    expected=quotas['identity_oracle'];people=quotas['primary_catalog_counts']['person']
    if counts['confirm']!=expected['confirmed_forest_joins_in_replay']:errors.append('Confirmation action count differs from quota')
    if counts['reject']!=expected['rejected_negative_pairs_in_replay']:errors.append('Rejection action count differs from quota')
    if joins!=expected['confirmed_forest_joins_in_replay']:errors.append(f"Only {joins} distinct forest joins are planned")
    if people-joins!=expected['public_groups_after_successful_confirmations']:errors.append(f"Plan would leave {people-joins} groups, not {expected['public_groups_after_successful_confirmations']}")
    return errors,{'planned_confirmations':counts['confirm'],'planned_rejections':counts['reject'],
                   'planned_distinct_forest_joins':joins,'redundant_confirmation_ids':cycles,
                   'projected_groups_if_valid_plan_executed':people-joins,'legacy_unexecutable_action_shapes':legacy}
