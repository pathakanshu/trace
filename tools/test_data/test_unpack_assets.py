"""Offline archive failure tests using tiny temporary bundles; no app/store access."""
import io
import json
from pathlib import Path
import stat
from tempfile import TemporaryDirectory
import unittest
import warnings
import zipfile
from unpack_assets import DATASET, MAX_BYTES, restore_bundle, sha

PREFIX=f'demo/assets/{DATASET}'
IMAGE=PREFIX+'/images/med-000001.png'
THUMB=PREFIX+'/thumbnails/med-000001.webp'


def package(root, files=None, entries=None, zip_names=None, symlink=False):
    files = files if files is not None else {IMAGE:b'fixture-image',THUMB:b'fixture-thumbnail'}
    items=entries if entries is not None else [{'path':name,'byte_size':len(content),'sha256':sha(content)} for name,content in files.items()]
    buffer=io.BytesIO()
    with warnings.catch_warnings(),zipfile.ZipFile(buffer,'w') as archive:
        warnings.simplefilter('ignore',UserWarning)
        for name in zip_names if zip_names is not None else files:
            info=zipfile.ZipInfo(name)
            if symlink:info.create_system=3;info.external_attr=(stat.S_IFLNK|0o777)<<16
            archive.writestr(info,files[name])
    payload=buffer.getvalue();bundle=root/'assets.zip';bundle.write_bytes(payload)
    data=root/'demo/datasets'/DATASET;data.mkdir(parents=True,exist_ok=True)
    (data/'manifest.json').write_text(json.dumps({'assets':items}))
    (data/'asset-distribution.json').write_text(json.dumps({'byte_size':len(payload),'sha256':sha(payload),'files':len(items),
        'images':sum(item['path'].startswith(PREFIX+'/images/') for item in items),
        'thumbnails':sum(item['path'].startswith(PREFIX+'/thumbnails/') for item in items)}))
    return bundle


class AssetUnpackerTests(unittest.TestCase):
    def test_valid_roundtrip_and_identical_rerun_preserve_mtimes(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);bundle=package(root)
            self.assertEqual(restore_bundle(bundle,root),{'files':2,'images':1,'thumbnails':1})
            before={name:((root/name).read_bytes(),(root/name).stat().st_mtime_ns) for name in (IMAGE,THUMB)}
            restore_bundle(bundle,root)
            self.assertEqual(before,{name:((root/name).read_bytes(),(root/name).stat().st_mtime_ns) for name in (IMAGE,THUMB)})

    def test_wrong_bundle_hash_or_size_writes_nothing(self):
        for content in (b'wrong length',None):
            with TemporaryDirectory() as folder:
                root=Path(folder);bundle=package(root)
                raw=bundle.read_bytes();bundle.write_bytes(content if content else bytes([raw[0]^1])+raw[1:])
                with self.assertRaisesRegex(ValueError,'Bundle size/SHA'):restore_bundle(bundle,root)
                self.assertFalse((root/PREFIX).exists())

    def test_missing_extra_or_duplicate_zip_members_write_nothing(self):
        for names in ([IMAGE],[IMAGE,THUMB,THUMB]):
            with TemporaryDirectory() as folder:
                root=Path(folder);bundle=package(root,zip_names=names)
                with self.assertRaisesRegex(ValueError,'ZIP inventory'):restore_bundle(bundle,root)
                self.assertFalse((root/PREFIX).exists())
        with TemporaryDirectory() as folder:
            root=Path(folder);files={IMAGE:b'one',THUMB:b'two',PREFIX+'/images/med-000002.png':b'extra'}
            entries=[{'path':name,'byte_size':len(files[name]),'sha256':sha(files[name])} for name in (IMAGE,THUMB)]
            bundle=package(root,files,entries)
            with self.assertRaisesRegex(ValueError,'ZIP inventory'):restore_bundle(bundle,root)

    def test_wrong_member_hash_or_declared_size_writes_nothing(self):
        for field,value in [('sha256','0'*64),('byte_size',999)]:
            with TemporaryDirectory() as folder:
                root=Path(folder);bundle=package(root)
                path=root/'demo/datasets'/DATASET/'manifest.json';manifest=json.loads(path.read_text());manifest['assets'][1][field]=value;path.write_text(json.dumps(manifest))
                with self.assertRaises(ValueError):restore_bundle(bundle,root)
                self.assertFalse((root/PREFIX).exists())

    def test_changed_existing_last_asset_prevents_first_file_write(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);bundle=package(root);target=root/THUMB;target.parent.mkdir(parents=True);target.write_bytes(b'user changed')
            with self.assertRaisesRegex(ValueError,'overwrite changed'):restore_bundle(bundle,root)
            self.assertFalse((root/IMAGE).exists());self.assertEqual(target.read_bytes(),b'user changed')

    def test_symlinked_asset_root_or_file_escape_is_rejected(self):
        for level in ('root','file'):
            with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
                root=Path(folder);bundle=package(root);target=root/(PREFIX if level=='root' else IMAGE)
                target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(Path(outside) if level=='root' else Path(outside)/'image.png',target_is_directory=level=='root')
                with self.assertRaisesRegex(ValueError,'escapes'):restore_bundle(bundle,root)
                self.assertEqual(list(Path(outside).iterdir()),[])
                self.assertFalse((root/THUMB).exists())

    def test_traversal_absolute_and_windows_paths_rejected(self):
        for name in (PREFIX+'/images/../../../../escape.png','/absolute/image.png',PREFIX+'/images/..\\escape.png'):
            with TemporaryDirectory() as folder:
                root=Path(folder);bundle=package(root,{name:b'inert'})
                with self.assertRaises(ValueError):restore_bundle(bundle,root)
                self.assertFalse((root/PREFIX).exists())

    def test_archive_symlink_and_existing_directory_rejected_before_writes(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);bundle=package(root,symlink=True)
            with self.assertRaisesRegex(ValueError,'regular file'):restore_bundle(bundle,root)
            self.assertFalse((root/PREFIX).exists())
        with TemporaryDirectory() as folder:
            root=Path(folder);bundle=package(root);(root/THUMB).mkdir(parents=True)
            with self.assertRaisesRegex(ValueError,'regular file'):restore_bundle(bundle,root)
            self.assertFalse((root/IMAGE).exists())

    def test_duplicate_manifest_and_size_budget_fail_without_allocating_payload(self):
        for change in ('duplicate','oversized','boolean'):
            with TemporaryDirectory() as folder:
                root=Path(folder);bundle=package(root);path=root/'demo/datasets'/DATASET/'manifest.json';manifest=json.loads(path.read_text())
                if change=='duplicate':manifest['assets'].append(manifest['assets'][0])
                else:manifest['assets'][0]['byte_size']=MAX_BYTES+1 if change=='oversized' else True
                path.write_text(json.dumps(manifest))
                with self.assertRaises(ValueError):restore_bundle(bundle,root)
                self.assertFalse((root/PREFIX).exists())

    def test_existing_parent_file_is_reported_before_any_asset_write(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);bundle=package(root);parent=(root/THUMB).parent;parent.parent.mkdir(parents=True);parent.write_text('keep')
            with self.assertRaisesRegex(ValueError,'parent is not a directory'):restore_bundle(bundle,root)
            self.assertFalse((root/IMAGE).exists());self.assertEqual(parent.read_text(),'keep')


if __name__=='__main__':unittest.main()
