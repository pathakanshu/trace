import copy
import unittest
from audit_support_needs import support_need_errors
from generate_queries import ROOT, read_catalog


def records():
    time='2016-07-05T18:15:00Z';incident='inc-000001'
    return [
        {'id':'per-000001','kind':'person','incident_id':incident,'available_at':time,'support_needs_claim_ids':['clm-000001']},
        {'id':'clm-000001','kind':'claim','incident_id':incident,'available_at':time,'source_id':'src-000001',
         'subject':{'kind':'person','id':'per-000001'},'assertion':{'text':'A fictional caller requests written instructions.'},
         'provenance':{'original_excerpt':'A fictional caller requests written instructions.'}},
        {'id':'src-000001','kind':'source','incident_id':incident,'available_at':time}]


class SupportNeedTests(unittest.TestCase):
    def test_matching_attributed_request_counts_once(self):
        rows=records();saved=copy.deepcopy(rows)
        errors,counts=support_need_errors(rows,1)
        self.assertEqual(errors,[]);self.assertEqual(counts['person_records_with_valid_support_citations'],1)
        self.assertEqual(rows,saved)

    def test_no_declared_support_requests_in_delivered_corpus_are_not_inferred(self):
        errors,counts=support_need_errors(list(read_catalog(ROOT).values()))
        self.assertEqual(counts['person_records_declaring_support_requests'],0)
        self.assertEqual(len(errors),1);self.assertIn('at least 30',errors[0])

    def test_missing_or_wrong_kind_claim_fails(self):
        for ident in ('clm-999999','src-000001'):
            rows=records();rows[0]['support_needs_claim_ids']=[ident]
            self.assertTrue(any('wrong-kind' in error for error in support_need_errors(rows,1)[0]))

    def test_claim_about_other_person_does_not_count(self):
        rows=records();rows[1]['subject']['id']='per-000002'
        errors,counts=support_need_errors(rows,1)
        self.assertTrue(any('another subject' in e for e in errors));self.assertEqual(counts['person_records_with_valid_support_citations'],0)

    def test_cross_incident_or_missing_source_fails(self):
        for mutation in ('claim_incident','source_incident','source_missing','source_kind'):
            rows=records()
            if mutation=='claim_incident':rows[1]['incident_id']='inc-000002'
            elif mutation=='source_incident':rows[2]['incident_id']='inc-000002'
            elif mutation=='source_missing':rows.pop()
            else:rows[2].update(kind='person',support_needs_claim_ids=[])
            self.assertTrue(any('attribution' in e for e in support_need_errors(rows,1)[0]))

    def test_future_claim_or_unpreserved_text_fails(self):
        for mutation in ('future','excerpt','blank'):
            rows=records()
            if mutation=='future':rows[1]['available_at']='2016-07-06T18:15:00Z'
            elif mutation=='excerpt':rows[1]['provenance']['original_excerpt']='Unrelated report'
            else:rows[1]['assertion']['text']=' '
            self.assertTrue(support_need_errors(rows,1)[0])

    def test_duplicate_citations_do_not_inflate_coverage(self):
        rows=records();rows[0]['support_needs_claim_ids']*=2
        errors,counts=support_need_errors(rows,1)
        self.assertTrue(any('duplicate' in e for e in errors));self.assertEqual(counts['person_records_with_valid_support_citations'],0)

    def test_multiple_citations_still_count_a_single_person(self):
        rows=records();extra=copy.deepcopy(rows[1]);extra['id']='clm-000002';rows.append(extra)
        rows[0]['support_needs_claim_ids'].append(extra['id'])
        errors,counts=support_need_errors(rows,2)
        self.assertEqual(counts['person_records_with_valid_support_citations'],1);self.assertEqual(len(errors),1)


if __name__=='__main__':unittest.main()
