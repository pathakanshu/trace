import hashlib
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from audit_sources import audit_sources
from generate_controls import build_controls, write_controls, DATASET
from generate_queries import ROOT, read_catalog


class SourceAuditTests(unittest.TestCase):
    def test_control_envelopes_counts_hashes_and_excerpts_pass(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);write_controls(root);rows,_=build_controls()
            integrity,envelopes,counts=audit_sources(root,rows,DATASET)
            self.assertEqual(integrity+envelopes,[])
            self.assertEqual(counts,{'sources_checked':2,'structured_sources':2,'text_sources':0,'claims_checked':10})

    def test_tamper_is_detected_even_when_json_stays_valid(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);write_controls(root);rows,_=build_controls()
            source=next(r for r in rows if r['kind']=='source');path=root/source['raw_path']
            path.write_bytes(path.read_bytes()+b' ')
            errors,_,_=audit_sources(root,rows,DATASET)
            self.assertTrue(any('SHA-256' in error for error in errors))

    def test_hash_correct_bad_envelope_and_locator_still_fail(self):
        for mutation in ('publisher','entries','original_content','extra'):
            with TemporaryDirectory() as folder:
                root=Path(folder);write_controls(root);rows,_=build_controls()
                source=next(r for r in rows if r['kind']=='source');path=root/source['raw_path']
                raw=json.loads(path.read_text())
                raw[mutation]={'kind':'organization','id':'org-899999'} if mutation=='publisher' else [] if mutation=='entries' else 'wrong'
                payload=json.dumps(raw).encode();path.write_bytes(payload);source['raw_sha256']=hashlib.sha256(payload).hexdigest()
                integrity,errors,_=audit_sources(root,rows,DATASET)
                self.assertEqual(integrity,[])
                self.assertTrue(errors,mutation)
        with TemporaryDirectory() as folder:
            root=Path(folder);write_controls(root);rows,_=build_controls()
            claim=next(r for r in rows if r['kind']=='claim');claim['provenance']['source_locator']='entries[99]'
            self.assertTrue(any('locator' in e for e in audit_sources(root,rows,DATASET)[1]))

    def test_escaping_symlink_is_rejected_without_reading_target(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);write_controls(root);rows,_=build_controls()
            source=next(r for r in rows if r['kind']=='source');path=root/source['raw_path']
            path.unlink();path.symlink_to(Path(outside)/'absent-do-not-read.json')
            errors,_,_=audit_sources(root,rows,DATASET)
            self.assertTrue(any('escapes' in error for error in errors))

    def test_published_sources_have_valid_bytes_but_legacy_structured_envelopes(self):
        errors,envelopes,counts=audit_sources(ROOT,list(read_catalog(ROOT).values()),DATASET)
        self.assertEqual(errors,[])
        self.assertEqual(counts,{'sources_checked':1800,'structured_sources':1260,'text_sources':540,'claims_checked':3600})
        self.assertEqual(len(envelopes),1260)
        self.assertTrue(all('original_content' in e for e in envelopes))


if __name__=='__main__':unittest.main()
