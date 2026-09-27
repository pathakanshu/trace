"""Actual decoder checks for negative fixture bytes; no accepted assets edited.

Run separately under a tooling Python containing Pillow when unavailable in the
schema-check environment. A skip is never reported as a passed decoder check.
"""
import base64
import io
import json
import unittest
from generate_invalid import png_pixel, ROOT, DATASET
try:
    from PIL import Image, UnidentifiedImageError
except ImportError:
    Image=None


@unittest.skipIf(Image is None,'Pillow unavailable: run this file in the media tooling environment')
class NegativeMediaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.cases=[json.loads(line) for line in (ROOT/'tests/fixtures'/DATASET/'invalid-inputs.jsonl').read_text().splitlines()]

    def test_corrupt_and_truncated_bytes_fail_real_decoder(self):
        for case in self.cases[24:26]:
            with self.subTest(case=case['id']),self.assertRaises((OSError,ValueError,SyntaxError)):
                with Image.open(io.BytesIO(base64.b64decode(case['input'],validate=True))) as img:img.load()

    def test_valid_png_control_is_real_and_measured_mime_disagrees(self):
        value=self.cases[30]['input'];payload=base64.b64decode(value['bytes_base64'],validate=True)
        self.assertEqual(payload,png_pixel())
        with Image.open(io.BytesIO(payload)) as img:
            img.load();self.assertEqual(img.size,(1,1));self.assertEqual(img.format,'PNG')
            self.assertNotEqual(Image.MIME[img.format],value['declared_mime_type'])

    def test_svg_is_unsupported_by_raster_decoder(self):
        with self.assertRaises(UnidentifiedImageError):
            Image.open(io.BytesIO(self.cases[31]['input'].encode('utf-8')))


if __name__=='__main__':unittest.main()
