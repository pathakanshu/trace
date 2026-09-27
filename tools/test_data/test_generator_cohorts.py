"""Candidate generator checks in temporary output, not a repaired public corpus."""
from collections import Counter
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import jsonschema
import generate_catalog as generator
from generate_queries import ROOT,DATASET,read_catalog
from audit_checkpoints import recompute,rumor_conflicts


def raw_hashes(root):
    return {path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (root/'demo/datasets'/DATASET/'raw/reports').glob('*')}


class CandidateCohortTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.published_before=raw_hashes(ROOT);cls.catalog=read_catalog(ROOT)
        cls.plan=json.loads((ROOT/'tests/fixtures'/DATASET/'allocation-plan.json').read_text())
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())
        cls.people,_,cls.groups=generator.build_people(cls.plan)
        cls.subjects=generator.build_subjects();cls.media=[{'id':r['id']} for r in cls.catalog.values() if r['kind']=='media']
        cls.output=TemporaryDirectory();cls.root=Path(cls.output.name)
        with patch.object(generator,'ROOT',cls.root):
            cls.claims,cls.sources,_=generator.build_claims_and_sources(cls.plan,cls.groups,*cls.subjects,cls.media,cls.people)
        cmap={r['id']:r for r in cls.claims}
        for row in cls.people:row['available_at']=cmap['clm-'+row['id'].split('-')[1]]['available_at']
        cls.records=cls.people+cls.sources+cls.claims

    @classmethod
    def tearDownClass(cls):cls.output.cleanup()

    def test_candidate_meets_all_seven_checkpoint_cohorts(self):
        checkpoints,errors=recompute(self.records,self.groups,self.quota)
        self.assertEqual(errors,[]);self.assertEqual(len(checkpoints),7)
        self.assertEqual(checkpoints[-1]['observed'],{'NOT_YET_REPORTED':0,'MISSING':650,'FOUND_SAFE':250,'INJURED':50,'UNRESOLVED':50})

    def test_candidate_keeps_exact_person_claim_type_and_source_cardinality_quotas(self):
        types=Counter(c['assertion']['type'] for c in self.claims if c['subject']['kind']=='person')
        self.assertEqual(dict(types),self.quota['person_claims_by_type'])
        per_source=Counter(c['source_id'] for c in self.claims)
        self.assertEqual(dict(Counter(str(per_source[s['id']]) for s in self.sources)),self.quota['sources']['claim_cardinality_histogram'])
        self.assertEqual(len(self.claims),3600);self.assertEqual(len(self.sources),1800)

    def test_all_ten_rumors_have_available_equal_or_unknown_time_opposition(self):
        rumors=[c for c in self.claims if c['assertion']['type']=='DECEASED']
        self.assertEqual(len(rumors),10);self.assertEqual(rumor_conflicts(self.records,self.groups),[])
        self.assertTrue(all(c['reported_at']['value']=='2016-07-06T11:15:00Z' for c in rumors))

    def test_allocated_claim_source_ids_and_initial_missing_claims_are_preserved(self):
        self.assertEqual({c['id']:c['source_id'] for c in self.claims},self.plan['claim_to_source'])
        for claim in self.claims:
            if int(claim['id'][-6:])<=1150:self.assertEqual(claim,self.catalog[claim['id']])

    def test_candidate_records_pass_schema_and_new_raw_hashes_match_temporary_files(self):
        schema=json.loads((ROOT/'demo/spec/trace-record.schema.json').read_text());validator=jsonschema.Draft202012Validator(schema,format_checker=jsonschema.FormatChecker())
        for row in self.records:
            error=next(validator.iter_errors(row),None);self.assertIsNone(error,(row['id'],str(error)))
        for source in self.sources:self.assertEqual(hashlib.sha256((self.root/source['raw_path']).read_bytes()).hexdigest(),source['raw_sha256'])
        # The raw envelope remains legacy; this is not complete importer acceptance.

    def test_published_reports_are_unchanged_and_their_old_defects_still_reported(self):
        self.assertEqual(raw_hashes(ROOT),self.published_before)
        checkpoints,errors=recompute(list(self.catalog.values()),self.groups,self.quota)
        self.assertEqual(checkpoints[-1]['observed']['FOUND_SAFE'],547)
        self.assertEqual(len(errors),2);self.assertEqual(len(rumor_conflicts(list(self.catalog.values()),self.groups)),6)

    def test_candidate_generation_is_deterministic_in_a_second_temporary_directory(self):
        with TemporaryDirectory() as folder,patch.object(generator,'ROOT',Path(folder)):
            claims,sources,_=generator.build_claims_and_sources(self.plan,self.groups,*self.subjects,self.media,self.people)
            self.assertEqual(claims,self.claims);self.assertEqual(sources,self.sources)
            self.assertEqual(raw_hashes(Path(folder)),raw_hashes(self.root))

    def test_generator_refuses_nonempty_published_output_before_loading_or_writing(self):
        for relative in ('records/person/part-0001.jsonl','raw/reports/source.txt'):
            with TemporaryDirectory() as folder:
                data=Path(folder);path=data/relative;path.parent.mkdir(parents=True);path.write_text('preserve me')
                with patch.object(generator,'DATA',data),patch.object(generator,'load_plan') as load:
                    with self.assertRaisesRegex(ValueError,'Refusing'):generator.main()
                    load.assert_not_called()
                self.assertEqual(path.read_text(),'preserve me')
        with TemporaryDirectory() as folder:
            generator.require_fresh_catalog_output(Path(folder))

    def test_generator_rejects_symlink_output_even_if_target_is_empty(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            data=Path(folder);(data/'records').symlink_to(Path(outside),target_is_directory=True)
            with self.assertRaises(ValueError):generator.require_fresh_catalog_output(data)
            self.assertEqual(list(Path(outside).iterdir()),[])


if __name__=='__main__':unittest.main()
