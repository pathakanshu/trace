import copy
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from generate_queries import ROOT,DATASET,read_catalog
from generate_licenses import build_licenses,validate_licenses,write_licenses,USAGE_BASIS,ATTRIBUTION,UNKNOWN_VERSION


class LicenseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT);data=ROOT/'demo/datasets'/DATASET
        cls.receipt=json.loads((data/'asset-measurements.json').read_text())
        cls.families=[json.loads(line) for line in (ROOT/'tests/fixtures'/DATASET/'oracle/media-families.jsonl').read_text().splitlines()]

    def fixture(self,root):
        family=self.families[0];ids={member['media_id'] for member in family['members']};rows=[self.catalog[ident] for ident in sorted(ids)]
        data=root/'demo/datasets'/DATASET;shard=data/'records/media/part-0001.jsonl';shard.parent.mkdir(parents=True)
        shard.write_text(''.join(json.dumps(row)+'\n' for row in rows))
        receipt=copy.deepcopy(self.receipt);receipt['images']=[item for item in receipt['images'] if item['media_id'] in ids]
        (data/'asset-measurements.json').write_text(json.dumps(receipt))
        oracle=root/'tests/fixtures'/DATASET/'oracle';oracle.mkdir(parents=True);(oracle/'media-families.jsonl').write_text(json.dumps(family)+'\n')
        license_path=data/'licenses.json';license_path.write_text(json.dumps([{'terms':USAGE_BASIS,'creator':ATTRIBUTION}]))
        for row in rows:
            path=root/row['asset_path'];path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((ROOT/row['asset_path']).read_bytes())
        return license_path,rows

    def test_complete_inventory_has_preserved_terms_hashes_and_explicit_unknown_version(self):
        value=build_licenses(self.catalog,self.families,self.receipt)
        self.assertEqual(validate_licenses(value,self.catalog,self.families,self.receipt),{'entries':200,'origins':{'generated':120,'derived':80},'original_encoder_version_recorded':False})
        for row in value['assets']:
            self.assertEqual(row['usage_basis'],USAGE_BASIS);self.assertEqual(row['tool']['version'],UNKNOWN_VERSION)
            self.assertEqual(row['license_id'],self.catalog[row['media_id']]['license_id'])
            self.assertEqual(row['artifact_sha256'],self.catalog[row['media_id']]['sha256'])
            self.assertNotIn('family_id',row);self.assertNotIn('parent_media_id',row)

    def test_saved_inventory_matches_the_measured_catalog_and_contract(self):
        value=json.loads((ROOT/'demo/datasets'/DATASET/'licenses.json').read_text())
        self.assertEqual(value,build_licenses(self.catalog,self.families,self.receipt))

    def test_mutated_rights_hash_version_or_extra_field_fails(self):
        for key,value in [('usage_basis','public domain'),('artifact_sha256','0'*64),('tool',{'name':'Pillow','version':'invented'}),('verified',True)]:
            rows=build_licenses(self.catalog,self.families,self.receipt);rows['assets'][0][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_licenses(rows,self.catalog,self.families,self.receipt)

    def test_duplicate_missing_and_unknown_family_origins_fail(self):
        for change in ('duplicate','missing','unknown'):
            families=copy.deepcopy(self.families)
            if change=='duplicate':families.append(families[0])
            if change=='missing':families.pop()
            if change=='unknown':families[0]['members'][0]['operation']='external_download'
            with self.assertRaises(ValueError):build_licenses(self.catalog,families,self.receipt)

    def test_unreconciled_creation_times_block_inventory_migration(self):
        catalog=copy.deepcopy(self.catalog);catalog['med-000001']['actual_created_at']='2026-09-27T07:06:00Z'
        with self.assertRaisesRegex(ValueError,'reconcile'):build_licenses(catalog,self.families,self.receipt)

    def test_write_preserves_binary_bytes_and_repeat_preserves_all_mtimes(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);path,rows=self.fixture(root)
            before={row['asset_path']:(root/row['asset_path']).read_bytes() for row in rows}
            self.assertEqual(write_licenses(root)['files_changed'],1)
            value=json.loads(path.read_text());self.assertEqual(len(value['assets']),2)
            for name,payload in before.items():self.assertEqual((root/name).read_bytes(),payload)
            stamp=path.stat().st_mtime_ns;payload=path.read_bytes()
            self.assertEqual(write_licenses(root)['files_changed'],0);self.assertEqual(path.read_bytes(),payload);self.assertEqual(path.stat().st_mtime_ns,stamp)

    def test_changed_usage_basis_or_damaged_asset_refuses_without_license_write(self):
        for change in ('terms','asset'):
            with TemporaryDirectory() as folder:
                root=Path(folder);path,rows=self.fixture(root)
                if change=='terms':path.write_text(json.dumps([{'terms':'different','creator':ATTRIBUTION}]))
                else:(root/rows[0]['asset_path']).write_bytes(b'corrupt')
                before=path.read_bytes()
                with self.assertRaises(ValueError):write_licenses(root)
                self.assertEqual(path.read_bytes(),before)

    def test_escaping_license_symlink_is_not_followed(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);path,_=self.fixture(root);target=Path(outside)/'licenses.json';target.write_bytes(path.read_bytes());path.unlink();path.symlink_to(target)
            before=target.read_bytes()
            with self.assertRaises(ValueError):write_licenses(root)
            self.assertEqual(target.read_bytes(),before)


if __name__=='__main__':unittest.main()
