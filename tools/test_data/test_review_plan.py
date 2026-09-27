import json
import unittest
from audit_review_plan import review_plan_errors
from generate_queries import ROOT,DATASET


def fixtures():
    groups=[{'id':'gid-000001','person_ids':['per-000001','per-000002','per-000003']},{'id':'gid-000002','person_ids':['per-000004']}]
    quota={'primary_catalog_counts':{'person':4},'identity_oracle':{'confirmed_forest_joins_in_replay':2,'rejected_negative_pairs_in_replay':1,'public_groups_after_successful_confirmations':2}}
    actions=[{'id':f'action-{i:06d}','operation':'review_identity','payload':{'person_a_id':a,'person_b_id':b,'decision':decision}} for i,(a,b,decision) in enumerate([
        ('per-000001','per-000002','confirm'),('per-000002','per-000003','confirm'),('per-000001','per-000004','reject')],1)]
    return actions,groups,quota


class ReviewPlanTests(unittest.TestCase):
    def test_valid_forest_and_rejection_do_not_overmerge(self):
        actions,groups,quota=fixtures();errors,observed=review_plan_errors(actions,groups,quota)
        self.assertEqual(errors,[]);self.assertEqual(observed['planned_distinct_forest_joins'],2)
        self.assertEqual(observed['projected_groups_if_valid_plan_executed'],2)

    def test_triangle_is_not_a_third_join(self):
        actions,groups,quota=fixtures();actions.append({'id':'action-000004','operation':'review_identity','payload':{'person_a_id':'per-000001','person_b_id':'per-000003','decision':'confirm'}})
        errors,observed=review_plan_errors(actions,groups,quota)
        self.assertEqual(observed['planned_distinct_forest_joins'],2)
        self.assertEqual(observed['redundant_confirmation_ids'],['action-000004'])
        self.assertTrue(any('cycle' in error for error in errors))

    def test_confirmation_or_rejection_disagreeing_with_private_labels_fails(self):
        for index,decision in ((0,'reject'),(2,'confirm')):
            actions,groups,quota=fixtures();actions[index]['payload']['decision']=decision
            self.assertTrue(any('conflicts' in error for error in review_plan_errors(actions,groups,quota)[0]))

    def test_self_missing_or_unknown_decision_fails(self):
        for key,value in [('person_b_id','per-000001'),('person_b_id','per-899999'),('decision','automatic_merge')]:
            actions,groups,quota=fixtures();actions[0]['payload'][key]=value
            self.assertTrue(review_plan_errors(actions,groups,quota)[0])

    def test_published_legacy_plan_has_78_joins_not_80(self):
        folder=ROOT/'tests/fixtures'/DATASET
        actions=[json.loads(line) for line in (folder/'replay/actions.jsonl').read_text().splitlines()]
        groups=[json.loads(line) for line in (folder/'oracle/identities.jsonl').read_text().splitlines()]
        quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())
        errors,observed=review_plan_errors(actions,groups,quota)
        self.assertEqual(observed['planned_confirmations'],80);self.assertEqual(observed['planned_rejections'],20)
        self.assertEqual(observed['planned_distinct_forest_joins'],78)
        self.assertEqual(observed['redundant_confirmation_ids'],['act-000011','act-000014'])
        self.assertEqual(observed['projected_groups_if_valid_plan_executed'],1072)
        self.assertEqual(observed['legacy_unexecutable_action_shapes'],100)
        self.assertEqual(len(errors),4)


if __name__=='__main__':unittest.main()
