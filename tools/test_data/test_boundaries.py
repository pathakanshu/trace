import copy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from audit_boundaries import (audit_boundaries, decode_districts, polygon_membership,
                              ring_membership, wgs84, BOUNDARY_REFERENCE)
from generate_queries import ROOT, read_catalog


# Synthetic mathematical fixtures, not proposed geographic data.
def topology(arcs=None, rings=None):
    return {'type':'Topology','arcs':arcs or [[[0,0],[4,0],[4,4],[0,4],[0,0]]],
            'objects':{'districts':{'type':'GeometryCollection','geometries':[
                {'type':'Polygon','properties':{'district_id':30},'arcs':rings or [[0]]}]}}}


def location(point=(1,1)):
    return {'kind':'location','id':'loc-000001','country_code':'NP',
            'geometry':{'type':'Point','coordinates':list(point)},
            'admin_refs':[{'level':'district','code':'30','boundary_reference':BOUNDARY_REFERENCE+'30'}]}


class BoundaryTests(unittest.TestCase):
    def test_real_catalog_points_match_full_declared_district_geometry(self):
        errors,counts=audit_boundaries(ROOT,list(read_catalog(ROOT).values()))
        self.assertEqual(errors,[]);self.assertEqual(counts['location_records_checked'],170)
        self.assertEqual(counts['distinct_point_district_checks'],4)
        self.assertEqual(counts['checked_district_codes'],['30']);self.assertEqual(counts['boundary_hits'],0)
        self.assertEqual(counts['geometry_sha256'],'23bb3510efadbd2b039eba18f21be5a3c47e13a9cba6dadc4a9f7e700ae2d885')

    def test_unquantized_negative_arcs_join_and_do_not_mutate(self):
        value=topology([[[0,0],[4,0],[4,4]],[[0,0],[0,4],[4,4]]],[[0,-2]])
        saved=copy.deepcopy(value);rings=decode_districts(value)['30']
        self.assertEqual(rings[0][0],[(0,0),(4,0),(4,4),(0,4),(0,0)])
        self.assertEqual(value,saved);self.assertEqual(polygon_membership((1,1),rings),'inside')

    def test_quantized_delta_coordinates_reset_for_each_arc_before_reversal(self):
        value=topology([[[0,0],[4,0],[0,4]],[[0,0],[0,4],[4,0]]],[[0,-2]])
        value['transform']={'scale':[0.5,0.25],'translate':[85,27]}
        ring=decode_districts(value)['30'][0][0]
        self.assertEqual(ring,[(85,27),(87,27),(87,28),(85,28),(85,27)])

    def test_hole_interior_excluded_and_hole_edge_is_explicit_boundary(self):
        value=topology([[[0,0],[4,0],[4,4],[0,4],[0,0]],[[1,1],[3,1],[3,3],[1,3],[1,1]]],[[0],[1]])
        polygons=decode_districts(value)['30']
        self.assertEqual(polygon_membership((2,2),polygons),'outside')
        self.assertEqual(polygon_membership((1,2),polygons),'boundary')
        self.assertEqual(polygon_membership((0.5,2),polygons),'inside')

    def test_concave_bbox_false_positive_is_rejected(self):
        ring=[(0,0),(4,0),(4,1),(1,1),(1,4),(0,4),(0,0)]
        self.assertEqual(ring_membership((3,3),ring),'outside')
        self.assertEqual(ring_membership((0.5,3),ring),'inside')
        self.assertEqual(ring_membership((0,0),ring),'boundary')
        self.assertEqual(ring_membership((4,0.5),ring),'boundary')
        self.assertEqual(ring_membership((0,4.01),ring),'outside')

    def test_multipolygon_checks_all_parts_and_ignores_ring_orientation(self):
        value=topology([[[0,0],[1,0],[1,1],[0,1],[0,0]],[[2,2],[3,2],[3,3],[2,3],[2,2]]])
        value['objects']['districts']['geometries'][0].update(type='MultiPolygon',arcs=[[[0]],[[-2]]])
        polygons=decode_districts(value)['30']
        self.assertEqual(polygon_membership((2.5,2.5),polygons),'inside')
        self.assertEqual(polygon_membership((1.5,1.5),polygons),'outside')

    def test_disconnected_unclosed_and_degenerate_rings_fail(self):
        for arcs,rings in [([[[0,0],[1,0]],[[2,0],[2,1],[0,0]]],[[0,1]]),
                           ([[[0,0],[1,0],[1,1],[0,1]]],[[0]]),
                           ([[[0,0],[1,0],[0,0]]],[[0]]),
                           ([[[0,0],[1,0],[2,0],[0,0]]],[[0]])]:
            with self.subTest(arcs=arcs),self.assertRaises(ValueError):decode_districts(topology(arcs,rings))

    def test_bad_arc_indices_nonfinite_and_bad_transform_fail(self):
        for index in (2,-3,True,0.5):
            with self.subTest(index=index),self.assertRaises(ValueError):decode_districts(topology(rings=[[index]]))
        for point in ((True,1),(float('nan'),1),(85,95),(200,27),(85,27,0)):
            with self.subTest(point=point),self.assertRaises(ValueError):wgs84(point)
        value=topology();value['transform']={'scale':[0,1],'translate':[0,0]}
        with self.assertRaises(ValueError):decode_districts(value)
        value['transform']['scale']=[1,1];value['arcs'][0][1][0]=4.5
        with self.assertRaisesRegex(ValueError,'integers'):decode_districts(value)

    def test_unknown_missing_duplicate_and_unusable_districts_do_not_pass(self):
        value=topology();geometry=value['objects']['districts']['geometries'][0]
        value['objects']['districts']['geometries'].append(copy.deepcopy(geometry))
        with self.assertRaisesRegex(ValueError,'duplicate'):decode_districts(value)
        with self.assertRaises(ValueError):decode_districts(topology(),{'999'})
        geometry['type']='LineString'
        with self.assertRaises(ValueError):decode_districts(value)

    def test_audit_checks_declared_district_country_type_and_point(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);(root/'geometry.topo.json').write_text(json.dumps(topology()))
            for change in ('outside','reference','code','missing_ref','country','geometry'):
                row=location()
                if change=='outside':row['geometry']['coordinates']=[5,1]
                elif change=='reference':row['admin_refs'][0]['boundary_reference']='other-file'
                elif change=='code':row['admin_refs'][0]['code']='999'
                elif change=='missing_ref':row['admin_refs']=[]
                elif change=='country':row['country_code']='CN'
                else:row['geometry']['type']='Polygon'
                try:errors,_=audit_boundaries(root,[row])
                except ValueError as error:errors=[str(error)]
                self.assertTrue(errors,change)

    def test_boundary_counts_are_distinct_from_inside_and_empty_does_not_pass(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);(root/'geometry.topo.json').write_text(json.dumps(topology()))
            errors,counts=audit_boundaries(root,[location((0,1))])
            self.assertEqual(errors,[]);self.assertEqual(counts['boundary_hits'],1)
            with self.assertRaises(ValueError):audit_boundaries(root,[])

    def test_unreferenced_malformed_district_is_not_silently_repaired(self):
        value=topology();other=copy.deepcopy(value['objects']['districts']['geometries'][0])
        other['properties']['district_id']=31;other['arcs']=[[999]]
        value['objects']['districts']['geometries'].append(other)
        self.assertEqual(set(decode_districts(value,{'30'})),{'30'})
        with self.assertRaises(ValueError):decode_districts(value)

    def test_external_boundary_symlink_is_rejected(self):
        with TemporaryDirectory() as folder,TemporaryDirectory() as elsewhere:
            root=Path(folder);(root/'geometry.topo.json').symlink_to(Path(elsewhere)/'boundary.json')
            with self.assertRaisesRegex(ValueError,'symlink'):audit_boundaries(root,[location()])


if __name__=='__main__':unittest.main()
