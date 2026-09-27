"""Ensure private fixture generators cannot hide malformed/duplicate inputs."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from generate_queries import DATASET, read_catalog, strict_json_loads
from audit_contracts import read_jsonl


class CatalogInputTests(unittest.TestCase):
    def shard(self,root,text,name='part-0001.jsonl'):
        path=root/'demo/datasets'/DATASET/'records/person'/name
        path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8')
        return path

    def test_valid_unicode_records_are_preserved_in_sorted_file_order(self):
        with TemporaryDirectory() as folder:
            root=Path(folder)
            self.shard(root,'{"id":"per-000002","name":"माया"}\n','part-0002.jsonl')
            self.shard(root,'{"id":"per-000001","age":null}\n')
            rows=read_catalog(root)
            self.assertEqual(list(rows),['per-000001','per-000002'])
            self.assertEqual(rows['per-000002']['name'],'माया')
            self.assertIsNone(rows['per-000001']['age'])

    def test_duplicate_id_in_same_or_other_shard_is_rejected(self):
        for same_file in (True,False):
            with TemporaryDirectory() as folder:
                root=Path(folder);row='{"id":"per-000001"}\n';self.shard(root,row*2 if same_file else row)
                if not same_file:self.shard(root,row,'part-0002.jsonl')
                with self.assertRaisesRegex(ValueError,'Duplicate primary'):read_catalog(root)

    def test_duplicate_json_keys_at_any_depth_and_nonfinite_numbers_fail(self):
        for text in ('{"id":"a","id":"b"}','{"id":"a","nested":{"x":1,"x":2}}','{"id":"a","x":NaN}','{"id":"a","x":Infinity}'):
            with self.subTest(text=text),self.assertRaises(ValueError):strict_json_loads(text)
            with TemporaryDirectory() as folder:
                path=Path(folder)/'fixture.jsonl';path.write_text(text+'\n')
                with self.assertRaises(ValueError):read_jsonl(path)

    def test_empty_blank_nonobject_and_unidentified_records_fail(self):
        for text in ('','\n','null\n','[]\n','{}\n','{"id":42}\n','{"id":""}\n','{"id":"per-000001"}\n\n'):
            with TemporaryDirectory() as folder:
                root=Path(folder);self.shard(root,text)
                with self.subTest(text=text),self.assertRaises(ValueError):read_catalog(root)

    def test_unterminated_invalid_json_and_invalid_utf8_fail(self):
        for payload in (b'{"id":"per-000001"}',b'{invalid}\n',b'\xff\n'):
            with TemporaryDirectory() as folder:
                root=Path(folder);path=self.shard(root,'');path.write_bytes(payload)
                with self.assertRaises(ValueError):read_catalog(root)

    def test_missing_catalog_is_not_silently_empty(self):
        with TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError,'No primary catalog'):read_catalog(Path(folder))

    def test_catalog_symlink_escape_is_rejected_before_read(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);path=self.shard(root,'');path.unlink()
            path.symlink_to(Path(outside)/'do-not-read.jsonl')
            with self.assertRaisesRegex(ValueError,'escapes'):read_catalog(root)


if __name__=='__main__':unittest.main()
