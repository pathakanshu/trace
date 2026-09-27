"""Dependency-failure regression: no cached schema result may substitute for a run."""
import contextlib
import importlib.util
import io
from pathlib import Path
import types
import unittest
from unittest.mock import patch


class LegacyValidationGuardTests(unittest.TestCase):
    def test_missing_schema_dependency_blocks_before_reading_cache_or_writing(self):
        path=Path(__file__).with_name('validate_dataset.py')
        spec=importlib.util.spec_from_file_location('legacy_validator_guard_test',path)
        module=importlib.util.module_from_spec(spec)
        # Pillow is irrelevant to this early dependency branch. This explicit
        # unit-test stub does not perform or claim any image verification.
        with patch.dict('sys.modules',{'PIL':types.SimpleNamespace(Image=None)}):
            spec.loader.exec_module(module)
        captured=io.StringIO()
        with patch.object(module,'jsonschema',None),patch.object(Path,'read_text',side_effect=AssertionError('must not consult cached reports')),patch.object(Path,'write_text',side_effect=AssertionError('must not write outputs')),contextlib.redirect_stderr(captured):
            self.assertEqual(module.main(),2)
        self.assertIn('Cached schema-validation.json is not accepted',captured.getvalue())
        self.assertIn('No files were written',captured.getvalue())


if __name__=='__main__':unittest.main()
