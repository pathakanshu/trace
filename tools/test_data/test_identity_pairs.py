import copy
import json
import unittest
from audit_identity_pairs import audit_pairs,normalized_name
from generate_queries import ROOT,DATASET,read_catalog


class PairBenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT);folder=ROOT/'tests/fixtures'/DATASET/'oracle'
        cls.pairs=[json.loads(line) for line in (folder/'identity-pairs.jsonl').read_text().splitlines()]
        cls.groups=[json.loads(line) for line in (folder/'identities.jsonl').read_text().splitlines()]
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())['identity_oracle']

    def audit(self,pairs=None,catalog=None):
        return audit_pairs(pairs if pairs is not None else self.pairs,self.groups,catalog if catalog is not None else self.catalog,self.quota)

    def test_all_private_combinations_labels_references_and_quotas_are_correct(self):
        labels,_,observed=self.audit()
        self.assertEqual(labels,[])
        self.assertEqual((observed['pairs'],observed['positive'],observed['negative']),(250,165,85))
        self.assertEqual(observed['same_name_and_age_negatives'],20)

    def test_twenty_negative_cases_have_identical_supplied_context_not_proof_of_rejection(self):
        _,errors,observed=self.audit()
        self.assertEqual(len(errors),20)
        self.assertEqual(observed['indistinguishable_cited_context'],20)
        self.assertTrue(errors[0].startswith('pair-000166'))

    def test_flipped_label_and_nonboolean_label_fail(self):
        for value in (False,'true'):
            pairs=copy.deepcopy(self.pairs);pairs[0]['same_individual']=value
            self.assertTrue(self.audit(pairs)[0])

    def test_reverse_duplicate_and_missing_positive_combination_fail(self):
        pairs=copy.deepcopy(self.pairs);pair=copy.deepcopy(pairs[0]);pair['id']='pair-999999'
        pair['person_a_id'],pair['person_b_id']=pair['person_b_id'],pair['person_a_id'];pairs.append(pair)
        self.assertTrue(any('Unordered' in e for e in self.audit(pairs)[0]))
        self.assertTrue(any('every within-identity' in e for e in self.audit(self.pairs[1:])[0]))

    def test_missing_or_one_sided_citations_fail(self):
        for evidence in (['clm-899999'],['per-000001'],[self.pairs[0]['evidence_claim_ids'][0]]):
            pairs=copy.deepcopy(self.pairs);pairs[0]['evidence_claim_ids']=evidence
            self.assertTrue(self.audit(pairs)[0])

    def test_actual_context_difference_avoids_identical_fingerprint_without_claiming_truth(self):
        catalog=copy.deepcopy(self.catalog);catalog['per-000022']['description']='Fictional contrasting household context supplied for this unit test only.'
        _,errors,observed=self.audit(catalog=catalog)
        self.assertEqual(observed['indistinguishable_cited_context'],19)
        self.assertFalse(any(error.startswith('pair-000166:') for error in errors))
        self.assertEqual(self.catalog['per-000022']['description'],self.catalog['per-000002']['description'])

    def test_name_normalization_uses_unicode_case_and_whitespace(self):
        self.assertEqual(normalized_name('  Ａｎｉｌ   RAI '),'anil rai')
        self.assertEqual(normalized_name('माया  गुरुङ'),'माया गुरुङ')


if __name__=='__main__':unittest.main()
