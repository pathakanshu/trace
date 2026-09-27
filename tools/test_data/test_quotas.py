import copy
import json
import unittest
from audit_quotas import quota_errors
from generate_queries import ROOT,read_catalog


class QuotaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records=list(read_catalog(ROOT).values())
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())

    def audit(self,records=None,quota=None):
        errors,dimensions=quota_errors(self.records if records is None else records,self.quota if quota is None else quota)
        return errors,{row['rule']:row for row in dimensions}

    def test_current_corpus_counts_are_measured_not_inherited_from_cached_reports(self):
        errors,dimensions=self.audit()
        self.assertEqual(len(dimensions),25)
        self.assertEqual(errors,['primary_catalog_counts: measured coverage differs from quota'])
        # Counts do not certify the independently diagnosed semantic failures.
        self.assertFalse(dimensions['primary_catalog_counts']['passed'])
        self.assertEqual(dimensions['primary_catalog_counts']['actual']['location'],170)
        self.assertEqual(dimensions['primary_catalog_counts']['expected']['location'],1000)
        self.assertEqual(dimensions['sources.claim_cardinality_histogram']['actual'],{'1':900,'2':500,'4':300,'5':100})
        self.assertEqual(dimensions['sources.declared_dependent']['actual'],450)

    def test_removed_claim_changes_histogram_subject_and_person_type(self):
        records=copy.deepcopy(self.records)
        records.remove(next(row for row in records if row['kind']=='claim' and row['subject']['kind']=='person'))
        _,dimensions=self.audit(records)
        for name in ('primary_catalog_counts','sources.claim_cardinality_histogram','claims_by_subject_kind','person_claims_by_type'):
            self.assertFalse(dimensions[name]['passed'],name)

    def test_unknown_subtype_cannot_hide_in_correct_primary_counts(self):
        for kind,field,key in [('facility','facility_type','facilities_by_type'),('task','task_type','community.task_types'),('organization','organization_type','organizations_by_type')]:
            records=copy.deepcopy(self.records);next(row for row in records if row['kind']==kind)[field]='UNSUPPORTED'
            _,dimensions=self.audit(records);self.assertFalse(dimensions[key]['passed'])

    def test_unpublished_organization_is_included_in_minimum(self):
        records=copy.deepcopy(self.records);organizations=[row for row in records if row['kind']=='organization'];victim=organizations[0]['id'];replacement=organizations[1]['id']
        for row in records:
            if row['kind']=='source' and row['publisher']=={'kind':'organization','id':victim}:row['publisher']['id']=replacement
        _,dimensions=self.audit(records);self.assertEqual(dimensions['sources.minimum_reports_per_organization']['actual'],0)
        self.assertFalse(dimensions['sources.minimum_reports_per_organization']['passed'])

    def test_dependency_coverage_counts_reports_not_number_of_edges(self):
        records=copy.deepcopy(self.records)
        source=next(row for row in records if row['kind']=='source' and row['dependencies']);source['dependencies']*=2
        _,dimensions=self.audit(records);self.assertEqual(dimensions['sources.declared_dependent']['actual'],450)
        # Duplicate edges must still fail separate relationship validation.

    def test_media_minimums_count_distinct_upload_ids_and_exactly_one(self):
        records=copy.deepcopy(self.records)
        for row in records:
            if row['kind']=='claim':row['supporting_media_ids']=['med-000001','med-000001']
        _,dimensions=self.audit(records)
        self.assertEqual(dimensions['images.uploads_cited_by_claim_minimum']['actual'],1)
        self.assertEqual(dimensions['images.claims_citing_exactly_one_upload_minimum']['actual'],3600)
        self.assertEqual(dimensions['images.claims_citing_two_or_more_uploads_minimum']['actual'],0)

    def test_nepali_minimum_requires_nonblank_english_rendering(self):
        records=copy.deepcopy(self.records)
        for row in records:
            if row['kind']=='contribution':row['english_rendering']='   '
        _,dimensions=self.audit(records);self.assertEqual(dimensions['community.nepali_with_english_rendering_minimum']['actual'],0)
        self.assertFalse(dimensions['community.nepali_with_english_rendering_minimum']['passed'])

    def test_computed_quota_change_is_honored_without_changing_records(self):
        quota=copy.deepcopy(self.quota);quota['primary_catalog_counts']['location']=170
        _,dimensions=self.audit(quota=quota);self.assertTrue(dimensions['primary_catalog_counts']['passed'])
        self.assertEqual(self.quota['primary_catalog_counts']['location'],1000)


if __name__=='__main__':unittest.main()
