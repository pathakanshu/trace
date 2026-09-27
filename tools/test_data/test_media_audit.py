"""Run with a Pillow-equipped Python; skips are explicitly not media passes."""
import copy
import hashlib
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from generate_invalid import png_pixel
try:
    from audit_media import inspect_image,property_errors,check_family_geometry,reproduce_derivative,creation_provenance_errors
    from PIL import Image
    PILLOW=True
except ImportError:
    PILLOW=False


@unittest.skipUnless(PILLOW,'Pillow unavailable: run media tests separately')
class MediaAuditTests(unittest.TestCase):
    def test_actual_decoded_properties_match_known_png_bytes(self):
        with TemporaryDirectory() as folder:
            path=Path(folder)/'image.png';payload=png_pixel();path.write_bytes(payload)
            actual=inspect_image(path)
            self.assertEqual(actual['sha256'],hashlib.sha256(payload).hexdigest())
            self.assertEqual(actual['byte_size'],len(payload));self.assertEqual((actual['width_px'],actual['height_px']),(1,1))
            self.assertEqual(actual['mime_type'],'image/png');self.assertFalse(actual['exif_present'])
            record={'id':'med-000001',**actual};self.assertEqual(property_errors(record,actual),[])
            record['width_px']=10;self.assertEqual(len(property_errors(record,actual)),1)

    def test_corrupt_image_is_not_reported_as_decoded(self):
        with TemporaryDirectory() as folder:
            path=Path(folder)/'image.png';path.write_bytes(png_pixel()[:24])
            with self.assertRaises((OSError,ValueError,SyntaxError)):inspect_image(path)

    def family(self,operation):
        params={'width_px':8,'height_px':6,'crop_box':[1,1,9,7],'metadata_policy':'strip'}
        family={'id':'fam-000001','family_class':{'byte_copy':'base_plus_exact_copy','resize':'base_plus_resize','crop':'base_plus_crop'}[operation],'base_media_id':'med-000001','members':[{'media_id':'med-000001','parent_media_id':None,'operation':'base','parameters':{}},
                {'media_id':'med-000002','parent_media_id':'med-000001','operation':operation,'parameters':params}]}
        base={'sha256':'a','width_px':10,'height_px':8,'format':'PNG','exif_present':True}
        child={'sha256':'b','width_px':8,'height_px':6,'format':'JPEG','exif_present':False}
        return family,{'med-000001':base,'med-000002':child}

    def test_exact_copy_requires_same_hash_and_transform_requires_changed_bytes(self):
        family,measured=self.family('byte_copy')
        self.assertTrue(check_family_geometry(family,measured));measured['med-000002']=copy.deepcopy(measured['med-000001'])
        self.assertEqual(check_family_geometry(family,measured),[])
        family['members'][1]['operation']='resize';family['family_class']='base_plus_resize'
        self.assertTrue(any('did not change' in e for e in check_family_geometry(family,measured)))

    def test_resize_crop_bounds_dimensions_and_metadata_are_checked(self):
        for operation in ('resize','crop'):
            family,measured=self.family(operation);self.assertEqual(check_family_geometry(family,measured),[])
            measured['med-000002']['exif_present']=True
            self.assertTrue(any('EXIF remains' in e for e in check_family_geometry(family,measured)))
        family,measured=self.family('crop');family['members'][1]['parameters']['crop_box']=[0,0,11,8]
        self.assertTrue(any('outside base' in e for e in check_family_geometry(family,measured)))
        family,measured=self.family('resize');measured['med-000002']['width_px']=7
        self.assertTrue(any('dimensions' in e for e in check_family_geometry(family,measured)))

    def test_wrong_family_class_or_multiple_derivatives_fail(self):
        family,measured=self.family('resize');family['family_class']='base_plus_exact_copy'
        self.assertTrue(any('operations differ' in e for e in check_family_geometry(family,measured)))
        family,measured=self.family('resize');family['members'].append(copy.deepcopy(family['members'][1]))
        self.assertTrue(any('operations differ' in e for e in check_family_geometry(family,measured)))

    def test_recipe_reproduction_is_deterministic_and_preserves_base_bytes(self):
        with TemporaryDirectory() as folder:
            path=Path(folder)/'base.png';path.write_bytes(png_pixel());before=path.read_bytes()
            for operation in ('resize','reencode','crop'):
                member={'operation':operation,'parameters':{'width_px':8,'height_px':6,'jpeg_quality':72,'crop_box':[0,0,1,1]}}
                payload=reproduce_derivative(path,member)
                self.assertEqual(payload,reproduce_derivative(path,member))
                with Image.open(io.BytesIO(payload)) as image:
                    image.load();self.assertEqual(image.format,'JPEG')
                    self.assertEqual(image.size,(8,6) if operation=='resize' else (1,1))
            self.assertEqual(path.read_bytes(),before)
            self.assertEqual([p.name for p in Path(folder).iterdir()],['base.png'])

    def test_unsupported_recipe_and_invalid_quality_fail_without_output_files(self):
        with TemporaryDirectory() as folder:
            path=Path(folder)/'base.png';path.write_bytes(png_pixel())
            for operation,quality in (('invented',72),('reencode',101),('reencode',True)):
                with self.assertRaises(ValueError):reproduce_derivative(path,{'operation':operation,'parameters':{'jpeg_quality':quality}})
            self.assertEqual(len(list(Path(folder).iterdir())),1)

    def test_missing_parent_or_decoded_member_fails(self):
        family,measured=self.family('resize');del measured['med-000002']
        self.assertTrue(any('missing decoded member' in e for e in check_family_geometry(family,measured)))
        family,measured=self.family('resize');family['members'][1]['parent_media_id']='med-899999'
        self.assertTrue(any('directly from base' in e for e in check_family_geometry(family,measured)))

    def provenance(self):
        from generate_queries import DATASET
        fields={'sha256':'a'*64,'byte_size':100,'width_px':10,'height_px':10,'mime_type':'image/png','exif_present':False,'gps_present':False}
        media=[{'id':'med-000001','asset_path':'images/a.png','actual_created_at':'2026-09-27T00:40:00Z'}]
        saved={'dataset_id':DATASET,'generated_at':'2026-09-27T00:42:47Z','images':[{'media_id':'med-000001','path':'images/a.png',**fields}]}
        return media,saved,{'med-000001':fields}

    def test_creation_precedes_measurement_and_bytes_match(self):
        media,saved,actual=self.provenance();self.assertEqual(creation_provenance_errors(media,saved,actual),[])
        media[0]['actual_created_at']=saved['generated_at']
        self.assertEqual(creation_provenance_errors(media,saved,actual),[])

    def test_creation_after_saved_measurement_is_a_provenance_failure(self):
        media,saved,actual=self.provenance();media[0]['actual_created_at']='2026-09-27T07:06:00Z'
        self.assertEqual(len(creation_provenance_errors(media,saved,actual)),1)
        self.assertIn('creation follows',creation_provenance_errors(media,saved,actual)[0])

    def test_measurement_coverage_duplicates_and_altered_bytes_fail(self):
        for change in ('missing','duplicate','hash','path','dataset'):
            media,saved,actual=self.provenance()
            if change=='missing':saved['images']=[]
            if change=='duplicate':saved['images']*=2
            if change=='hash':saved['images'][0]['sha256']='b'*64
            if change=='path':saved['images'][0]['path']='images/other.png'
            if change=='dataset':saved['dataset_id']='another-dataset'
            with self.subTest(change=change):self.assertTrue(creation_provenance_errors(media,saved,actual))

    def test_unknown_or_invalid_creation_and_measurement_times_fail(self):
        for target in ('creation','measurement'):
            for value in (None,'unknown','2016-01-01','2026-09-27T00:42:47+00:00','2026-02-30T00:00:00Z'):
                media,saved,actual=self.provenance()
                if target=='creation':media[0]['actual_created_at']=value
                else:saved['generated_at']=value
                with self.subTest(target=target,value=value):self.assertTrue(creation_provenance_errors(media,saved,actual))



if __name__=='__main__':unittest.main()
