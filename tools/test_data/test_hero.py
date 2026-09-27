import copy
import json
import shutil
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from audit_contracts import read_jsonl
from generate_hero import ROOT,DATASET,load_inputs,select_hero,hero_errors,write_hero


class HeroTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records,cls.plan,cls.groups,cls.families,cls.quotas=load_inputs(ROOT)
        cls.directory=ROOT/'tests/fixtures'/DATASET/'hero'

    def test_saved_profile_matches_catalog_and_has_closed_dependencies(self):
        rows=[r for path in sorted(self.directory.glob('*.jsonl')) for r in read_jsonl(path)]
        manifest=json.loads((self.directory/'manifest.json').read_text())
        self.assertEqual(hero_errors(rows,self.records,self.plan,manifest,self.groups,self.families,self.quotas),[])
        self.assertEqual(len(rows),748)
        self.assertEqual(sum(r['kind']=='person' for r in rows),62)
        self.assertEqual(sum(r['kind']=='media' for r in rows),40)
        self.assertTrue({'inc-000001','loc-000841','loc-000925'}<={r['id'] for r in rows})

    def test_selected_person_subscriptions_and_contributors_are_retained(self):
        rows=select_hero(self.records,self.plan);people={r['id'] for r in rows if r['kind']=='person'}
        expected={r['id'] for r in self.records if r['kind']=='subscription' and r['subject']['kind']=='person' and r['subject']['id'] in people}
        subscriptions=[r for r in rows if r['kind']=='subscription']
        self.assertEqual({r['id'] for r in subscriptions},expected);self.assertEqual(len(subscriptions),62)
        ids={r['id'] for r in rows}
        self.assertTrue(all(r['contributor_id'] in ids for r in subscriptions))

    def test_unselected_person_followers_do_not_expand_the_hero(self):
        rows=[{'id':'inc-000001','kind':'incident','incident_id':'inc-000001'}]
        for n in (1,2):
            rows.extend([{'id':f'per-{n:06d}','kind':'person','incident_id':'inc-000001'},
                {'id':f'act-{n:06d}','kind':'contributor','incident_id':'inc-000001'},
                {'id':f'sub-{n:06d}','kind':'subscription','incident_id':'inc-000001','contributor_id':f'act-{n:06d}',
                 'subject':{'kind':'person','id':f'per-{n:06d}'}}])
        plan={'hero_person_ids':['per-000001'],'hero_media_ids':[],'story_plans':[]}
        self.assertEqual({r['id'] for r in select_hero(rows,plan)},{'inc-000001','per-000001','act-000001','sub-000001'})

    def test_selection_is_deterministic_and_does_not_mutate_catalog(self):
        original=copy.deepcopy(self.records)
        self.assertEqual(select_hero(self.records,self.plan),select_hero(list(reversed(self.records)),self.plan))
        self.assertEqual(original,self.records)

    def test_missing_dependency_fails_instead_of_silently_dropping_it(self):
        for ident in ('inc-000001','loc-000841','loc-000925'):
            with self.subTest(ident=ident),self.assertRaisesRegex(ValueError,ident):
                select_hero([r for r in self.records if r['id']!=ident],self.plan)

    def test_tampered_duplicate_or_incomplete_profile_is_reported(self):
        rows=select_hero(self.records,self.plan);manifest=json.loads((self.directory/'manifest.json').read_text())
        altered=copy.deepcopy(rows);altered[0]['available_at']='2016-07-09T00:00:00Z'
        for broken in (altered,rows+rows[:1],[r for r in rows if r['kind']!='incident']):
            self.assertTrue(hero_errors(broken,self.records,self.plan,manifest,self.groups,self.families,self.quotas))

    def test_generic_refs_keep_correction_ids_as_claims_and_incidents(self):
        rows=[{'id':'inc-000001','kind':'incident','incident_id':'inc-000001'},
              {'id':'per-000001','kind':'person','incident_id':'inc-000001'},
              {'id':'clm-000001','kind':'claim','incident_id':'inc-000001','source_id':'src-000001','subject':{'kind':'person','id':'per-000001'},'corrects_claim_ids':['clm-000002']},
              {'id':'clm-000002','kind':'claim','incident_id':'inc-000001','source_id':'src-000002','subject':{'kind':'person','id':'per-000001'}},
              {'id':'src-000001','kind':'source','incident_id':'inc-000001'},
              {'id':'src-000002','kind':'source','incident_id':'inc-000001'}]
        plan={'hero_person_ids':['per-000001'],'hero_media_ids':[],'story_plans':[]}
        self.assertEqual(len(select_hero(rows,plan)),6)

    def prepare_inputs(self, root):
        fixtures=root/'tests/fixtures'/DATASET
        for name in ('allocation-plan.json','oracle/identities.jsonl','oracle/media-families.jsonl'):
            target=fixtures/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/'tests/fixtures'/DATASET/name,target)
        (root/'demo/spec').mkdir(parents=True)
        shutil.copyfile(ROOT/'demo/spec/quotas.json',root/'demo/spec/quotas.json')
        catalog=root/'demo/datasets'/DATASET/'records/all.jsonl'
        catalog.parent.mkdir(parents=True)
        catalog.write_text(''.join(json.dumps(row)+'\n' for row in self.records))
        return catalog

    def test_repeat_export_preserves_bytes_mtimes_and_primary_records(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);catalog=self.prepare_inputs(root);original=catalog.read_bytes()
            first=write_hero(root)
            directory=root/'tests/fixtures'/DATASET/'hero'
            before={p.name:(p.read_bytes(),p.stat().st_mtime_ns) for p in directory.iterdir()}
            self.assertEqual(first,write_hero(root))
            self.assertEqual(before,{p.name:(p.read_bytes(),p.stat().st_mtime_ns) for p in directory.iterdir()})
            self.assertEqual(original,catalog.read_bytes())

    def test_escaping_hero_directory_is_rejected_before_writing(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);self.prepare_inputs(root)
            (root/'tests/fixtures'/DATASET/'hero').symlink_to(outside,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'escapes'):write_hero(root)
            self.assertEqual(list(Path(outside).iterdir()),[])

    def test_duplicate_primary_id_is_not_silently_collapsed(self):
        with self.assertRaisesRegex(ValueError,'Duplicate'):
            select_hero(self.records+self.records[:1],self.plan)


if __name__=='__main__':unittest.main()
