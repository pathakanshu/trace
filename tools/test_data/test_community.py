import copy
import json
import unittest
from audit_community import community_errors
from generate_queries import ROOT,DATASET,read_catalog,at


def good_records():
    return [
        {'id':'per-000001','kind':'person'},{'id':'per-000002','kind':'person'},
        {'id':'con-000001','kind':'contribution','contributor_id':'act-000001','target':{'kind':'media','id':'med-000001'},'submitted_at':at(24)},
        {'id':'vot-000001','kind':'vote','contributor_id':'act-000002','contribution_id':'con-000001'},
        {'id':'tsk-000001','kind':'task','state':'REVIEWED','assignee_id':'act-000001','target':{'kind':'media','id':'med-000001'},'submission_contribution_ids':['con-000001'],
         'review':{'reviewed_at':at(25),'evidence_claim_ids':['clm-000001']},'available_at':at(26)},
        *[{'id':f'sub-{i:06d}','kind':'subscription','contributor_id':actor,'subject':{'kind':kind,'id':ident},'active':True,'delivery':'in_app'}
          for i,(actor,kind,ident) in enumerate([('act-000001','person','per-000001'),('act-000002','person','per-000001'),('act-000001','location','loc-000001')],1)]]


class CommunityAuditTests(unittest.TestCase):
    def test_valid_votes_tasks_and_followers_pass_without_runtime_results(self):
        errors,observed=community_errors(good_records(),['per-000001'])
        self.assertTrue(all(not value for value in errors.values()))
        self.assertEqual(observed['max_distinct_hero_followers'],2)

    def test_self_votes_and_duplicate_pairs_are_separate_errors(self):
        rows=good_records();vote=next(r for r in rows if r['kind']=='vote');vote['contributor_id']='act-000001'
        duplicate=copy.deepcopy(vote);duplicate['id']='vot-000002';rows.append(duplicate)
        errors,observed=community_errors(rows,['per-000001'])
        self.assertEqual(observed['self_votes'],2)
        self.assertEqual(observed['duplicate_vote_pairs'],1)
        self.assertEqual(len(errors['community_vote_rules']),3)

    def test_task_must_cite_same_target_and_review_after_submission_before_release(self):
        rows=good_records();task=next(r for r in rows if r['kind']=='task')
        task['target']={'kind':'claim','id':'clm-000001'};task['review']['reviewed_at']=at(23);task['review']['evidence_claim_ids']=[]
        errors,_=community_errors(rows,['per-000001'])
        self.assertEqual(len(errors['task_submission_and_review']),3)
        task['review']['reviewed_at']=at(27)
        self.assertTrue(any('follows task release' in e for e in community_errors(rows,['per-000001'])[0]['task_submission_and_review']))

    def test_duplicate_or_inactive_followers_do_not_satisfy_two_people(self):
        rows=good_records();second=next(r for r in rows if r['id']=='sub-000002');second['contributor_id']='act-000001'
        errors,observed=community_errors(rows,['per-000001'])
        self.assertEqual(observed['max_distinct_hero_followers'],1)
        self.assertTrue(any('duplicate subscription' in e for e in errors['subscription_coverage_and_uniqueness']))
        second['contributor_id']='act-000002';second['active']=False
        self.assertEqual(community_errors(rows,['per-000001'])[1]['max_distinct_hero_followers'],1)

    def test_submitted_missing_and_open_workflow_contradictions_fail(self):
        rows=good_records();task=next(r for r in rows if r['kind']=='task')
        task.update(state='SUBMITTED',assignee_id=None,submission_contribution_ids=[])
        self.assertTrue(community_errors(rows,['per-000001'])[0]['task_submission_and_review'])
        task.update(state='OPEN',assignee_id='act-000001')
        self.assertTrue(any('open task' in e for e in community_errors(rows,['per-000001'])[0]['task_submission_and_review']))

    def test_current_partial_corpus_defects_are_reported_not_silently_repaired(self):
        rows=list(read_catalog(ROOT).values());plan=json.loads((ROOT/'tests/fixtures'/DATASET/'allocation-plan.json').read_text())
        errors,observed=community_errors(rows,plan['hero_person_ids'])
        self.assertEqual(observed['self_votes'],360)
        self.assertEqual(observed['duplicate_vote_pairs'],120)
        self.assertEqual(observed['task_submission_target_mismatches'],36)
        self.assertEqual(observed['max_distinct_hero_followers'],1)
        self.assertTrue(all(errors.values()))


if __name__=='__main__':unittest.main()
