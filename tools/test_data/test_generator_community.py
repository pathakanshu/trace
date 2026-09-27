"""Candidate community inputs only; no actual vote, follow, review or alert."""
from collections import Counter
import copy
import json
import unittest
import jsonschema
import generate_catalog as generator
from generate_queries import ROOT,DATASET,read_catalog
from audit_community import community_errors


class CandidateCommunityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT);cls.original=list(cls.catalog.values())
        cls.contributors=[row for row in cls.original if row['kind']=='contributor']
        cls.claim_sources={r['id']:r['source_id'] for r in cls.original if r['kind']=='claim'}
        cls.media_sources={r['id']:r['source_id'] for r in cls.original if r['kind']=='media'}
        cls.contributions,cls.votes,cls.tasks=generator.build_community(cls.contributors,cls.claim_sources,cls.media_sources)
        cls.subscriptions,_=generator.build_followups(cls.media_sources)
        cls.hero=json.loads((ROOT/'tests/fixtures'/DATASET/'allocation-plan.json').read_text())['hero_person_ids']
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())

    def test_vote_quota_unique_pairs_and_no_author_self_votes(self):
        contributions={row['id']:row for row in self.contributions}
        self.assertEqual(len(self.votes),360)
        self.assertEqual(dict(Counter(row['value'] for row in self.votes)),self.quota['community']['vote_values'])
        self.assertEqual(len({(row['contributor_id'],row['contribution_id']) for row in self.votes}),360)
        for row in self.votes:self.assertNotEqual(row['contributor_id'],contributions[row['contribution_id']]['contributor_id'])
        self.assertEqual(dict(Counter(Counter(row['contribution_id'] for row in self.votes).values())),{1:120,2:120})

    def test_votes_do_not_precede_their_submission_or_release(self):
        contributions={row['id']:row for row in self.contributions}
        for vote in self.votes:
            contribution=contributions[vote['contribution_id']]
            self.assertGreaterEqual(vote['voted_at'],contribution['submitted_at'])
            self.assertGreaterEqual(vote['available_at'],contribution['available_at'])
            self.assertEqual(vote['available_at'],vote['voted_at'])

    def test_subscription_quotas_include_two_hero_followers_and_unfollowed_people(self):
        self.assertEqual(dict(Counter(row['subject']['kind'] for row in self.subscriptions)),self.quota['subscriptions_by_subject_kind'])
        followers={r['contributor_id'] for r in self.subscriptions if r['active'] and r['subject']=={'kind':'person','id':'per-000001'}}
        self.assertEqual(len(followers),2)
        self.assertTrue(all(r['available_at']=='2016-07-06T00:15:00Z' for r in self.subscriptions if r['subject']['kind']!='media'))
        self.assertNotIn('per-000100',{r['subject']['id'] for r in self.subscriptions})

    def test_candidate_vote_task_and_follow_structural_rules_pass(self):
        rows=[r for r in self.original if r['kind'] not in ('vote','subscription','contribution','task')]+self.contributions+self.votes+self.tasks+self.subscriptions
        errors,counts=community_errors(rows,self.hero)
        self.assertEqual(errors['community_vote_rules'],[]);self.assertEqual(errors['subscription_coverage_and_uniqueness'],[])
        self.assertEqual(errors['task_submission_and_review'],[])
        self.assertEqual(counts['self_votes'],0);self.assertEqual(counts['duplicate_vote_pairs'],0)
        self.assertEqual(counts['max_distinct_hero_followers'],2)

    def test_candidate_schema_and_id_allocation_are_preserved(self):
        schema=json.loads((ROOT/'demo/spec/trace-record.schema.json').read_text());validator=jsonschema.Draft202012Validator(schema,format_checker=jsonschema.FormatChecker())
        for kind,rows in [('vote',self.votes),('subscription',self.subscriptions)]:
            self.assertEqual({r['id'] for r in rows},{r['id'] for r in self.original if r['kind']==kind})
            for row in rows:self.assertTrue(validator.is_valid(row),row['id'])

    def test_repeat_generation_preserves_inputs_and_published_defects_remain(self):
        before=copy.deepcopy(self.contributors)
        self.assertEqual(generator.build_community(self.contributors,self.claim_sources,self.media_sources),(self.contributions,self.votes,self.tasks))
        self.assertEqual(self.contributors,before)
        _,counts=community_errors(list(read_catalog(ROOT).values()),self.hero)
        self.assertEqual(counts['self_votes'],360);self.assertEqual(counts['duplicate_vote_pairs'],120)
        self.assertEqual(counts['max_distinct_hero_followers'],1)

    def test_task_submissions_match_type_target_assignee_and_review_evidence(self):
        contributions={row['id']:row for row in self.contributions}
        accepted={'GEOLOCATE':'GEOLOCATION','TRANSLATE':'TRANSLATION','FIND_EARLIER_COPY':'EARLIER_COPY','SOURCE_OR_CHALLENGE':'SOURCE_CITATION'}
        for task in self.tasks:
            self.assertLessEqual(task['created_at'],task['updated_at']);self.assertEqual(task['updated_at'],task['available_at'])
            for ident in task['submission_contribution_ids']:
                contribution=contributions[ident]
                self.assertEqual(contribution['target'],task['target']);self.assertEqual(contribution['contributor_id'],task['assignee_id'])
                self.assertEqual(contribution['contribution_type'],accepted[task['task_type']])
                self.assertLessEqual(task['created_at'],contribution['submitted_at'])
                self.assertLessEqual(contribution['submitted_at'],task['available_at'])
                if task['review']:
                    self.assertNotEqual(task['review']['contributor_id'],task['assignee_id'])
                    self.assertIn('reviewer',self.catalog[task['review']['contributor_id']]['roles'])
                    self.assertTrue(task['review']['evidence_claim_ids'])
                    for cid in task['review']['evidence_claim_ids']:
                        self.assertIn(self.catalog[cid]['source_id'],contribution['evidence_source_ids'])
                        self.assertLessEqual(self.catalog[cid]['available_at'],task['review']['reviewed_at'])

    def test_candidate_community_references_and_lifecycle_do_not_leak_future_records(self):
        from audit_contracts import reference_errors,lifecycle_errors
        kinds={'contribution','vote','task','subscription'}
        rows=[r for r in self.original if r['kind'] not in kinds]+self.contributions+self.votes+self.tasks+self.subscriptions
        missing,cross,future=reference_errors(rows)
        self.assertEqual(missing,[]);self.assertEqual(cross,[])
        self.assertEqual(future,[])
        self.assertEqual(lifecycle_errors(rows),[])
        for sub in self.subscriptions:
            self.assertGreaterEqual(sub['available_at'],self.catalog[sub['subject']['id']]['available_at'])
            self.assertEqual(sub['created_at'],sub['available_at'])

    def test_task_counts_schema_and_missing_reviewer_preflight(self):
        self.assertEqual(dict(Counter(row['state'] for row in self.tasks)),self.quota['community']['task_states'])
        self.assertEqual(dict(Counter(row['task_type'] for row in self.tasks)),self.quota['community']['task_types'])
        validator=jsonschema.Draft202012Validator(json.loads((ROOT/'demo/spec/trace-record.schema.json').read_text()),format_checker=jsonschema.FormatChecker())
        for row in self.tasks+self.contributions:self.assertTrue(validator.is_valid(row),row['id'])
        contributors=copy.deepcopy(self.contributors)
        for contributor in contributors:contributor['roles']=['volunteer']
        with self.assertRaisesRegex(ValueError,'reviewer'):generator.build_community(contributors,self.claim_sources,self.media_sources)

    def test_duplicate_missing_or_insufficient_contributors_are_rejected(self):
        for contributors in (self.contributors[:2],self.contributors+self.contributors[:1],self.contributors[:-1]):
            with self.assertRaises(ValueError):generator.build_community(contributors,self.claim_sources,self.media_sources)


if __name__=='__main__':unittest.main()
