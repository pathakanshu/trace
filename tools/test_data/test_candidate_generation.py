"""End-to-end fixture generator rehearsal in disposable storage, never the app."""
from collections import Counter
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import jsonschema
import generate_catalog as generator
from generate_queries import ROOT,DATASET,read_catalog
from generate_hero import write_hero
from audit_contracts import reference_errors,lifecycle_errors
from audit_checkpoints import recompute,rumor_conflicts
from audit_sources import audit_sources
from audit_community import community_errors
from audit_quotas import quota_errors


def hashes(directory):
    return {p.relative_to(directory).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.rglob('*') if p.is_file() and p.suffix not in ('.pyc',)}


class CandidateGenerationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output=TemporaryDirectory();cls.root=Path(cls.output.name).resolve()
        cls.data=cls.root/'demo/datasets'/DATASET;cls.fixtures=cls.root/'tests/fixtures'/DATASET
        cls.published_data=ROOT/'demo/datasets'/DATASET;cls.published_assets=ROOT/'demo/assets'/DATASET
        cls.before_data=hashes(cls.published_data);cls.before_assets=hashes(cls.published_assets)
        for name in ('quotas.json','trace-record.schema.json'):
            target=cls.root/'demo/spec'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'demo/spec'/name,target)
        cls.data.mkdir(parents=True);shutil.copyfile(cls.published_data/'asset-measurements.json',cls.data/'asset-measurements.json')
        shutil.copytree(cls.published_data/'context',cls.data/'context')
        shutil.copytree(cls.published_assets,cls.root/'demo/assets'/DATASET)
        for name in ('allocation-plan.json','oracle/identity-pairs.jsonl','oracle/media-families.jsonl'):
            target=cls.fixtures/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'tests/fixtures'/DATASET/name,target)
        with patch.multiple(generator,ROOT=cls.root,DATA=cls.data,FIX=cls.fixtures,ASSETS=cls.root/'demo/assets'/DATASET),redirect_stdout(io.StringIO()) as printed:
            generator.main()
        cls.generated_counts=json.loads(printed.getvalue());cls.catalog=read_catalog(cls.root);cls.rows=list(cls.catalog.values())
        cls.quota=json.loads((cls.root/'demo/spec/quotas.json').read_text());cls.plan=json.loads((cls.fixtures/'allocation-plan.json').read_text())
        cls.groups=[json.loads(line) for line in (cls.fixtures/'oracle/identities.jsonl').read_text().splitlines()]

    @classmethod
    def tearDownClass(cls):cls.output.cleanup()

    def test_full_candidate_schema_and_counts_match_except_documented_geography(self):
        validator=jsonschema.Draft202012Validator(json.loads((self.root/'demo/spec/trace-record.schema.json').read_text()),format_checker=jsonschema.FormatChecker())
        for row in self.rows:
            error=next(validator.iter_errors(row),None);self.assertIsNone(error,(row['id'],str(error)))
        self.assertEqual(len(self.rows),8027);self.assertEqual(self.generated_counts,dict(Counter(row['kind'] for row in self.rows)))
        errors,_=quota_errors(self.rows,self.quota);self.assertEqual(errors,['primary_catalog_counts: measured coverage differs from quota'])
        self.assertEqual(self.generated_counts['location'],170)

    def test_full_candidate_references_and_lifecycle_are_closed(self):
        self.assertEqual(reference_errors(self.rows),([],[],[]));self.assertEqual(lifecycle_errors(self.rows),[])

    def test_full_candidate_checkpoints_and_rumor_opposition_pass(self):
        checkpoints,errors=recompute(self.rows,self.groups,self.quota)
        self.assertEqual(errors,[]);self.assertEqual(len(checkpoints),7);self.assertEqual(rumor_conflicts(self.rows,self.groups),[])

    def test_full_candidate_original_source_envelopes_and_community_rules_pass(self):
        integrity,envelopes,counts=audit_sources(self.root,self.rows,DATASET)
        self.assertEqual(integrity+envelopes,[]);self.assertEqual(counts['claims_checked'],3600)
        errors,_=community_errors(self.rows,self.plan['hero_person_ids'])
        self.assertTrue(all(not findings for findings in errors.values()),errors)

    def test_full_candidate_can_export_fifty_identity_hero_with_reference_closure(self):
        result=write_hero(self.root)
        manifest=json.loads((self.fixtures/'hero/manifest.json').read_text())
        self.assertEqual(manifest['identity_group_count'],50);self.assertEqual(result['counts']['person'],62)
        rows=[json.loads(line) for path in (self.fixtures/'hero').glob('*.jsonl') for line in path.read_text().splitlines()]
        self.assertEqual(reference_errors(rows),([],[],[]));self.assertTrue(all(row==self.catalog[row['id']] for row in rows))
        followers={r['contributor_id'] for r in rows if r['kind']=='subscription' and r['active'] and r['subject']=={'kind':'person','id':'per-000001'}}
        self.assertEqual(len(followers),2)

    def test_candidate_support_requests_are_early_attributed_and_not_diagnoses(self):
        from audit_support_needs import support_need_errors
        errors,counts=support_need_errors(self.rows)
        self.assertEqual(errors,[]);self.assertEqual(counts['person_records_with_valid_support_citations'],30)
        people=[p for p in self.rows if p['kind']=='person' and p['support_needs_claim_ids']]
        self.assertEqual(len(people),30)
        requests=set()
        for person in people:
            self.assertEqual(len(person['support_needs_claim_ids']),1)
            claim=self.catalog[person['support_needs_claim_ids'][0]]
            expected=generator.reported_support_request(int(person['id'][-6:]))
            self.assertTrue(claim['assertion']['text'].endswith(expected))
            self.assertIn(expected,claim['provenance']['original_excerpt']);requests.add(expected)
            self.assertEqual(claim['assertion']['type'],'MISSING')
            self.assertEqual(claim['available_at'],person['available_at'])
        self.assertEqual(len(requests),5)

    def test_candidate_pair_context_differs_without_changing_names_ages_or_private_labels(self):
        from audit_identity_pairs import audit_pairs
        pairs=[json.loads(line) for line in (self.fixtures/'oracle/identity-pairs.jsonl').read_text().splitlines()]
        labels,context,counts=audit_pairs(pairs,self.groups,self.catalog,self.quota['identity_oracle'])
        self.assertEqual(labels+context,[]);self.assertEqual(counts['same_name_and_age_negatives'],20)
        self.assertEqual(counts['indistinguishable_cited_context'],0)
        # Reused household descriptions cannot act as globally unique group keys.
        descriptions=[generator.reported_household_context(i) for i in range(1,1001)]
        self.assertLess(len(set(descriptions)),100)
        self.assertEqual(self.catalog['per-000002']['display_name'],self.catalog['per-000022']['display_name'])
        self.assertEqual(self.catalog['per-000002']['reported_age'],self.catalog['per-000022']['reported_age'])

    def test_actual_copied_assets_match_candidate_records_and_published_bytes(self):
        self.assertEqual(hashes(self.root/'demo/assets'/DATASET),self.before_assets)
        for row in self.rows:
            if row['kind']=='media':
                payload=(self.root/row['asset_path']).read_bytes()
                self.assertEqual(hashlib.sha256(payload).hexdigest(),row['sha256']);self.assertEqual(len(payload),row['byte_size'])

    def test_original_dataset_and_assets_unchanged_and_no_runtime_store_created(self):
        self.assertEqual(hashes(self.published_data),self.before_data);self.assertEqual(hashes(self.published_assets),self.before_assets)
        self.assertFalse((self.root/'.jac').exists());self.assertFalse((self.root/'.trace-local').exists())
        before=hashes(self.data)
        with patch.object(generator,'DATA',self.data):
            with self.assertRaisesRegex(ValueError,'Refusing'):generator.main()
        self.assertEqual(hashes(self.data),before)


if __name__=='__main__':unittest.main()
