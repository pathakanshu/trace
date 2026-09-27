from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from generate_queries import DATASET,write_fixture_jsonl


class FixtureWriteTests(unittest.TestCase):
    def test_exact_repeat_preserves_bytes_and_mtime(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);rows=[{'id':'query-000001','text':'माया'}]
            write_fixture_jsonl(root,'queries.jsonl',rows)
            path=root/'tests/fixtures'/DATASET/'queries.jsonl';before=(path.read_bytes(),path.stat().st_mtime_ns)
            write_fixture_jsonl(root,'queries.jsonl',rows)
            self.assertEqual(before,(path.read_bytes(),path.stat().st_mtime_ns))

    def test_escaping_directory_file_and_lexical_paths_are_rejected(self):
        for level in ('directory','file'):
            with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
                root=Path(folder);directory=root/'tests/fixtures'/DATASET
                path=directory if level=='directory' else directory/'queries.jsonl'
                path.parent.mkdir(parents=True);path.symlink_to(Path(outside) if level=='directory' else Path(outside)/'absent',target_is_directory=level=='directory')
                with self.assertRaisesRegex(ValueError,'escapes'):write_fixture_jsonl(root,'queries.jsonl',[{}])
                self.assertEqual(list(Path(outside).iterdir()),[])
        with TemporaryDirectory() as folder:
            for path in ('../escape.jsonl','/absolute.jsonl','oracle/../escape.jsonl','oracle\\escape.jsonl'):
                with self.subTest(path=path),self.assertRaises(ValueError):write_fixture_jsonl(Path(folder),path,[{}])

    def test_nonfinite_output_is_rejected_before_creating_files(self):
        with TemporaryDirectory() as folder:
            root=Path(folder)
            with self.assertRaises(ValueError):write_fixture_jsonl(root,'queries.jsonl',[{'bad':float('nan')}])
            self.assertEqual(list(root.iterdir()),[])


if __name__=='__main__':unittest.main()
