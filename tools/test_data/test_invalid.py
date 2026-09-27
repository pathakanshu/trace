"""Negative fixture checks using real parsers/schema/references, never the app."""
import base64
import copy
import json
import unittest
from pathlib import PurePosixPath
import jsonschema
from audit_contracts import references, lifecycle_errors, reject_nonfinite, utc
from generate_controls import build_controls
from generate_invalid import build_cases, validate_cases, ROOT, DATASET, read_catalog


class InvalidFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=read_catalog(ROOT)
        cls.cases=[json.loads(line) for line in (ROOT/'tests/fixtures'/DATASET/'invalid-inputs.jsonl').read_text().splitlines()]
        cls.quota=json.loads((ROOT/'demo/spec/quotas.json').read_text())['evaluation']['invalid_input_categories']
        cls.validator=jsonschema.Draft202012Validator(json.loads((ROOT/'demo/spec/trace-record.schema.json').read_text()),format_checker=jsonschema.FormatChecker())

    def test_shapes_quotas_uniqueness_and_determinism(self):
        validate_cases(self.cases,self.quota)
        self.assertEqual(self.cases,build_cases(dict(reversed(list(self.catalog.items())))))
        self.assertEqual(len(self.cases),40)

    def test_baseline_records_are_valid_before_mutation(self):
        for ident in ('per-000001','clm-000001','clm-003301','src-000001'):
            self.validator.validate(self.catalog[ident])
        claim=self.catalog['clm-000001'];source=self.catalog[claim['source_id']]
        self.assertEqual(lifecycle_errors([claim,source]),[])

    def test_malformed_bytes_really_fail_standard_decoders(self):
        for case in self.cases[:3]:
            with self.subTest(case=case['id']),self.assertRaises(ValueError):
                json.loads(case['input'],parse_constant=reject_nonfinite)
        with self.assertRaises(UnicodeDecodeError):
            base64.b64decode(self.cases[3]['input'],validate=True).decode('utf-8')

    def test_missing_wrong_typed_and_private_fields_fail_actual_schema(self):
        for case in self.cases[4:8]+[self.cases[9]]+self.cases[16:20]+[self.cases[22]]:
            with self.subTest(case=case['id']):
                self.assertFalse(self.validator.is_valid(case['input']))

    def test_bad_refs_are_missing_or_cross_existing_control_incidents(self):
        controls,_=build_controls()
        catalog={**self.catalog,**{row['id']:row for row in controls}}
        for case in self.cases[8:16]:
            if case['expected_error_class']=='catalog_schema':continue
            row=case['input'];self.validator.validate(row)
            refs=[catalog.get(ident) for _,ident in references(row)]
            with self.subTest(case=case['id']):
                if case['expected_error_class']=='missing_reference':
                    self.assertTrue(any(target is None for target in refs))
                else:
                    self.assertTrue(all(target is not None for target in refs))
                    self.assertTrue(any(target['incident_id']!=row['incident_id'] for target in refs))

    def test_time_inconsistencies_are_semantic_not_parser_inventions(self):
        row=self.cases[20]['input'];self.validator.validate(row)
        self.assertGreater(utc(row['reported_at']['range_start']),utc(row['reported_at']['range_end']))
        row=self.cases[21]['input'];self.validator.validate(row)
        self.assertTrue(any('observation follows' in error for error in lifecycle_errors([row,self.catalog[row['source_id']]])))
        row=self.cases[23]['input'];self.validator.validate(row)
        self.assertTrue(any('published after release' in error for error in lifecycle_errors([row])))

    def test_missing_and_unsafe_paths_are_never_opened(self):
        path=ROOT/self.cases[26]['input']['asset_path']
        self.assertFalse(path.exists())
        self.assertIn('..',PurePosixPath(self.cases[27]['input']['asset_path']).parts)
        self.assertTrue(PurePosixPath(self.cases[28]['input']['asset_path']).is_absolute())
        # No read/stat of either rejected outside path.

    def test_byte_limit_uses_actual_bytes_and_explicit_bounded_limit(self):
        value=self.cases[29]['input']
        payload=base64.b64decode(value['bytes_base64'],validate=True)
        self.assertEqual(len(payload),1025)
        self.assertGreater(len(payload),value['max_bytes'])

    def test_runtime_procedures_are_unexecuted_with_real_references(self):
        for case in self.cases[32:]:
            self.assertTrue(case['required_capability'].startswith('runtime.'))
            self.assertEqual(case['expected_record_delta'],0)
            self.assertEqual(case['precondition_action_ids'],[])
            self.assertNotIn('actual_result',case)
            if isinstance(case['input'],dict):
                for field,value in case['input'].items():
                    if field.endswith('_id'):self.assertIn(value,self.catalog)
        self.assertIn('setup',self.cases[32]['input'])
        self.assertEqual(self.cases[34]['input']['repeat_count'],2)

    def test_shape_validator_rejects_placeholders_result_fields_bad_encoding_and_phantom_actions(self):
        for field,value in [('actual_result','passed'),('precondition_action_ids',['action-999999']),('input_encoding','pickle'),('expected_record_delta',True)]:
            cases=copy.deepcopy(self.cases);cases[0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):validate_cases(cases,self.quota)
        cases=copy.deepcopy(self.cases);cases[1]['input']=cases[0]['input']
        with self.assertRaises(ValueError):validate_cases(cases,self.quota)
        cases=copy.deepcopy(self.cases);cases[3]['input']='invalid base64!'
        with self.assertRaises(ValueError):validate_cases(cases,self.quota)


if __name__=='__main__':unittest.main()
