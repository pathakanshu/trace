import copy
import gzip
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from audit_geography import audit_context,audit_location_anchors,positions,source_geometry
from generate_queries import ROOT,DATASET,read_catalog


class GeographyAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        folder=ROOT/'demo/datasets'/DATASET/'context'
        cls.geography=json.loads((folder/'geography.geojson').read_text())
        cls.history={json.loads(line)['id'] for line in (folder/'historical-references.jsonl').read_text().splitlines()}

    def miniature(self,root):
        # Deliberately tiny unit-test archive, not delivered geographic evidence.
        feature=copy.deepcopy(self.geography['features'][1]);props=feature['properties']
        feature['geometry']={'type':'Point','coordinates':[85.0,28.0]};props['source_feature_id']='node/1'
        archive={'osm3s':{'timestamp_osm_base':props['source_version']},'elements':[{'type':'node','id':1,'lon':85.0,'lat':28.0}]}
        payload=gzip.compress(json.dumps(archive).encode(),mtime=0)
        path=root/'demo/datasets'/DATASET/'context/geographic-inputs/unit.json.gz';path.parent.mkdir(parents=True);path.write_bytes(payload)
        props['source_artifact_path']=path.relative_to(root).as_posix();props['source_artifact_sha256']=hashlib.sha256(payload).hexdigest()
        return {'type':'FeatureCollection','features':[feature]},path

    def test_archived_real_context_and_existing_anchors_match(self):
        errors,observed=audit_context(ROOT,self.geography,self.history,DATASET)
        self.assertEqual(errors,[])
        self.assertEqual(observed,{'context_features':5,'features_matching_archive':5,'preserved_archives':1,'referenced_osm_nodes_or_ways':8})
        errors,observed=audit_location_anchors(list(read_catalog(ROOT).values()),self.geography)
        self.assertEqual(errors,[]);self.assertEqual(observed['location_records'],170)
        self.assertEqual(observed['distinct_point_coordinates'],4)

    def test_changed_coordinates_hash_version_and_unknown_references_fail(self):
        for mutation in ('coordinates','hash','version','history','extra'):
            with TemporaryDirectory() as folder:
                root=Path(folder);geo,_=self.miniature(root);f=geo['features'][0]
                if mutation=='coordinates':f['geometry']['coordinates'].reverse()
                elif mutation=='hash':f['properties']['source_artifact_sha256']='0'*64
                elif mutation=='version':f['properties']['source_version']='2016-07-05T00:00:00Z'
                elif mutation=='history':f['properties']['historical_reference_ids']=['hist-899999']
                else:f['properties']['verified_flood_boundary']=True
                self.assertTrue(audit_context(root,geo,self.history,DATASET)[0],mutation)

    def test_archived_source_id_must_resolve(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);geo,_=self.miniature(root);geo['features'][0]['properties']['source_feature_id']='node/899999'
            self.assertTrue(any('missing' in e for e in audit_context(root,geo,self.history,DATASET)[0]))

    def test_escaping_geographic_archive_symlink_is_rejected(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as outside:
            root=Path(folder);geo,path=self.miniature(root);path.unlink();path.symlink_to(Path(outside)/'do-not-read.gz')
            self.assertTrue(any('escapes' in e for e in audit_context(root,geo,self.history,DATASET)[0]))

    def test_anchor_mismatch_or_missing_context_does_not_pass(self):
        catalog=read_catalog(ROOT);row=copy.deepcopy(catalog['loc-000001']);row['geometry']['coordinates'][0]+=0.01
        self.assertTrue(audit_location_anchors([row],self.geography)[0])
        row['coordinate_provenance']['context_feature_ids']=['geo-899999']
        self.assertTrue(any('missing context' in e for e in audit_location_anchors([row],self.geography)[0]))

    def test_degenerate_lines_and_invalid_positions_fail(self):
        with self.assertRaises(ValueError):positions({'type':'MultiLineString','coordinates':[[[85,28]]]})
        with TemporaryDirectory() as folder:
            root=Path(folder);geo,_=self.miniature(root);geo['features'][0]['geometry']['coordinates']=[200,95]
            self.assertTrue(any('WGS84' in e for e in audit_context(root,geo,self.history,DATASET)[0]))

    def test_multiline_preserves_disconnected_way_geometry(self):
        elements={('way',1):{'type':'way','geometry':[{'lon':85,'lat':28},{'lon':86,'lat':28}]},
                  ('way',2):{'type':'way','geometry':[{'lon':87,'lat':28},{'lon':88,'lat':28}]}}
        feature={'properties':{'source_feature_id':'way/1,way/2'},'geometry':{'type':'MultiLineString'}}
        self.assertEqual(source_geometry(feature,elements)['coordinates'],[[[85,28],[86,28]],[[87,28],[88,28]]])


if __name__=='__main__':unittest.main()
