import copy
import json
import unittest
from generate_identities import build_identities,validate_identities,ROOT,DATASET,read_catalog


class IdentityFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT);fixtures=ROOT/'tests/fixtures'/DATASET
        cls.plan=json.loads((fixtures/'allocation-plan.json').read_text())
        cls.geography=json.loads((ROOT/'demo/datasets'/DATASET/'context/geography.geojson').read_text())
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())['identity_oracle']
        cls.rows=[json.loads(line) for line in (fixtures/'oracle/identities.jsonl').read_text().splitlines()]

    def test_saved_closed_contract_preserves_all_allocated_ids_members_and_ages(self):
        validate_identities(self.rows,self.catalog,self.plan,self.geography,self.quota)
        for row,allocated in zip(self.rows,self.plan['identity_groups']):
            self.assertEqual(row['id'],allocated['identity_id'])
            self.assertEqual(row['person_ids'],allocated['person_ids'])
            self.assertEqual(row['canonical_age'],allocated['canonical_age'])
            self.assertEqual(row['primary_person_id'],allocated['primary_person_id'])

    def test_unavailable_geography_stays_unknown_without_invented_placeholders(self):
        known=[r for r in self.rows if r['initial_precision']=='point'];unknown=[r for r in self.rows if r['initial_precision']=='unknown']
        self.assertEqual(len(known),50);self.assertEqual(len(unknown),950)
        self.assertTrue(all(r['initial_location_id'] is None and r['initial_cluster'] is None for r in unknown))
        self.assertTrue(all(self.catalog[r['initial_location_id']]['geometry']['type']=='Point' for r in known))

    def test_missing_primary_membership_or_initial_claim_fails(self):
        plan=copy.deepcopy(self.plan);plan['identity_groups'][0]['primary_person_id']='per-899999'
        with self.assertRaises(ValueError):build_identities(self.catalog,plan,self.geography)
        plan=copy.deepcopy(self.plan);plan['identity_groups'][0]['initial_claim_ids']=[]
        with self.assertRaises(ValueError):build_identities(self.catalog,plan,self.geography)

    def test_unknown_geographic_cluster_is_rejected_instead_of_guessed(self):
        geography=copy.deepcopy(self.geography)
        for feature in geography['features']:
            if feature['id']=='geo-000002':feature['properties']['label']='Unmapped label'
        with self.assertRaisesRegex(ValueError,'cluster'):build_identities(self.catalog,self.plan,geography)

    def test_repeated_members_private_age_errors_and_extra_runtime_fields_fail(self):
        for mutation in ('member','age','decision'):
            rows=copy.deepcopy(self.rows)
            if mutation=='member':rows[1]['person_ids']=rows[0]['person_ids']
            elif mutation=='age':rows[0]['canonical_age']=True
            else:rows[0]['confirmed']=True
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate_identities(rows,self.catalog,self.plan,self.geography,self.quota)

    def test_fabricated_location_or_primary_record_does_not_match_report(self):
        rows=copy.deepcopy(self.rows);rows[0]['initial_location_id']='loc-000002'
        with self.assertRaisesRegex(ValueError,'actual initial-report'):validate_identities(rows,self.catalog,self.plan,self.geography,self.quota)

    def test_input_order_does_not_change_identity_output(self):
        plan=copy.deepcopy(self.plan);plan['identity_groups'].reverse()
        self.assertEqual(build_identities(self.catalog,plan,self.geography),self.rows)


if __name__=='__main__':unittest.main()
