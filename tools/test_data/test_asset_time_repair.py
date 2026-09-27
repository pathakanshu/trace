import copy
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from generate_queries import ROOT,DATASET,read_catalog
from repair_media_time import generation_start,correct_media_rows,plan_repair,repair


def encoded(rows):return (''.join(json.dumps(row,ensure_ascii=False,separators=(',',':'))+'\n' for row in rows)).encode()
def snapshot(root):return {p.relative_to(root).as_posix():(hashlib.sha256(p.read_bytes()).hexdigest(),p.stat().st_mtime_ns) for p in root.rglob('*') if p.is_file()}


class AssetTimeRepairTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT);data=ROOT/'demo/datasets'/DATASET
        cls.receipt=json.loads((data/'asset-measurements.json').read_text());cls.receipt['images']=cls.receipt['images'][:2]
        cls.legacy=json.loads((data/'generation-status.json').read_text())['generated_at']
        cls.rows=[copy.deepcopy(cls.catalog[item['media_id']]) for item in cls.receipt['images']]
        for row in cls.rows:row['actual_created_at']=cls.legacy

    def fixture(self,root):
        data=root/'demo/datasets'/DATASET;hero=root/'tests/fixtures'/DATASET/'hero'
        shard=data/'records/media/part-0001.jsonl';shard.parent.mkdir(parents=True);shard.write_bytes(encoded(self.rows))
        hero.mkdir(parents=True);(hero/'media.jsonl').write_bytes(encoded(self.rows))
        manifest={'record_shards':[{'path':shard.relative_to(root).as_posix(),'sha256':hashlib.sha256(shard.read_bytes()).hexdigest(),'byte_size':shard.stat().st_size,'records':2}], 'assets':[]}
        for row in self.rows:
            for field in ('asset_path','thumbnail_path'):
                target=root/row[field];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/row[field]).read_bytes())
                manifest['assets'].append({'path':row[field],'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'byte_size':target.stat().st_size})
        (data/'asset-measurements.json').write_text(json.dumps(self.receipt));(data/'generation-status.json').write_text(json.dumps({'generated_at':self.legacy}));(data/'manifest.json').write_text(json.dumps(manifest))
        spec=root/'demo/spec';spec.mkdir(parents=True);(spec/'quotas.json').write_text(json.dumps({'images':{'uploads':2},'seed':self.receipt['seed']}))
        raw=data/'raw/reports/untouched.txt';raw.parent.mkdir(parents=True);raw.write_text('FICTIONAL original source, preserve bytes.\n')
        return data,hero

    def test_only_creation_field_changes_and_input_is_preserved(self):
        before=copy.deepcopy(self.rows);result=correct_media_rows(self.rows,self.receipt,self.legacy)
        self.assertEqual(self.rows,before)
        for old,new in zip(before,result):
            self.assertEqual([key for key in old if old[key]!=new[key]],['actual_created_at'])
            self.assertEqual(new['actual_created_at'],self.receipt['generated_at'])

    def test_invalid_or_unrecognized_receipt_is_refused(self):
        for key,value in [('generated_at',None),('generated_at','2026-02-30T00:00:00Z'),('generated_at','2016-07-05'),('generator','unrecorded'),('dataset_id','different')]:
            receipt=copy.deepcopy(self.receipt);receipt[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):generation_start(receipt)

    def test_unknown_existing_time_or_changed_measurements_are_not_overwritten(self):
        for key,value in [('actual_created_at','2026-09-28T00:00:00Z'),('sha256','0'*64),('width_px',99),('asset_path','other.png')]:
            rows=copy.deepcopy(self.rows);rows[0][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):correct_media_rows(rows,self.receipt,self.legacy)

    def test_receipt_coverage_requires_unique_complete_media_membership(self):
        for items in (self.receipt['images'][:1],self.receipt['images']*2):
            receipt=copy.deepcopy(self.receipt);receipt['images']=items
            with self.assertRaises(ValueError):correct_media_rows(self.rows,receipt,self.legacy)

    def test_full_preflight_is_read_only_and_repair_refreshes_hero_and_manifest(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);data,hero=self.fixture(root);before=snapshot(root)
            pending,report=plan_repair(root);self.assertEqual(snapshot(root),before);self.assertEqual(report['media_records_changed'],2)
            self.assertEqual(report['asset_files_verified'],4);self.assertEqual(report['files_changed'],3)
            self.assertEqual(repair(root),report)
            after=snapshot(root);changed={name for name in before if before[name]!=after[name]}
            self.assertEqual(changed,{p.relative_to(root.resolve()).as_posix() for p in pending})
            self.assertEqual((hero/'media.jsonl').read_bytes(),(data/'records/media/part-0001.jsonl').read_bytes())
            manifest=json.loads((data/'manifest.json').read_text());item=manifest['record_shards'][0]
            self.assertEqual(item['sha256'],hashlib.sha256((root/item['path']).read_bytes()).hexdigest())
            self.assertEqual(repair(root)['files_changed'],0);self.assertEqual(snapshot(root),after)

    def test_damaged_asset_aborts_without_any_metadata_write(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);self.fixture(root);(root/self.rows[0]['asset_path']).write_bytes(b'corrupt')
            before=snapshot(root)
            with self.assertRaisesRegex(ValueError,'asset bytes'):repair(root)
            self.assertEqual(snapshot(root),before)

    def test_stale_manifest_or_mismatched_hero_aborts_before_any_write(self):
        for defect in ('manifest','hero'):
            with TemporaryDirectory() as folder:
                root=Path(folder);data,hero=self.fixture(root)
                if defect=='manifest':
                    path=data/'manifest.json';value=json.loads(path.read_text());value['record_shards'][0]['sha256']='0'*64;path.write_text(json.dumps(value))
                else:
                    rows=copy.deepcopy(self.rows);rows[0]['description']='unexpected edit';(hero/'media.jsonl').write_bytes(encoded(rows))
                before=snapshot(root)
                with self.assertRaises(ValueError):repair(root)
                self.assertEqual(snapshot(root),before)

    def test_escaping_destination_symlink_is_rejected(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);data,_=self.fixture(root);path=data/'manifest.json';target=Path(outside)/'manifest.json';target.write_bytes(path.read_bytes());path.unlink();path.symlink_to(target)
            before=target.read_bytes()
            with self.assertRaises(ValueError):repair(root)
            self.assertEqual(target.read_bytes(),before)

    def test_catalog_generator_uses_receipt_time_not_current_clock(self):
        import generate_catalog
        with TemporaryDirectory() as folder:
            root=Path(folder);data,_=self.fixture(root)
            sources={r['id']:r for r in self.catalog.values() if r['kind']=='source'};claims=[r for r in self.catalog.values() if r['kind']=='claim']
            before=snapshot(root)
            with patch.object(generate_catalog,'DATA',data),patch.object(generate_catalog,'NOW_ISO','2099-01-01T00:00:00Z'):
                rows=generate_catalog.build_media(sources,claims)
            self.assertTrue(all(row['actual_created_at']==self.receipt['generated_at'] for row in rows))
            self.assertEqual(snapshot(root),before)


if __name__=='__main__':unittest.main()
