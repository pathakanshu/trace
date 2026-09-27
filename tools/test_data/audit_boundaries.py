"""Read-only point membership in the supplied Nepal display district polygons.

TopoJSON decoding follows https://github.com/topojson/topojson-specification .
This is a planar lon/lat check for these local polygons, not a general GIS engine,
terrain validation, uncertainty-envelope test or reconstruction of 2016 borders.
"""
import hashlib
import math
from generate_queries import strict_json_loads

BOUNDARY_REFERENCE = 'geometry.topo.json:districts/district_id='
EPSILON = 1e-10  # degrees; numerical edge tolerance, never a geographic buffer


def position(value):
    if not isinstance(value, (list, tuple)) or len(value) != 2 or any(
            type(v) not in (int, float) or not math.isfinite(v) for v in value):
        raise ValueError('Expected two finite numeric coordinates')
    return tuple(value)


def wgs84(value):
    x, y = position(value)
    if not (-180 <= x <= 180 and -90 <= y <= 90):
        raise ValueError('Position outside WGS84 longitude/latitude range')
    return x, y


def decode_districts(topology, required_codes=None):
    """Decode referenced rings; reject broken joins instead of inventing segments."""
    if topology.get('type') != 'Topology':
        raise ValueError('Expected Topology')
    collection = topology['objects']['districts']
    if collection.get('type') != 'GeometryCollection':
        raise ValueError('Expected district GeometryCollection')
    transform = topology.get('transform')
    if transform is not None:
        scale = position(transform['scale']); translate = position(transform['translate'])
        if any(v <= 0 for v in scale):
            raise ValueError('Expected positive transform scales')
    cache = {}

    def arc(index):
        if type(index) is not int:
            raise ValueError('Arc index must be an integer')
        key = index if index >= 0 else ~index
        if not 0 <= key < len(topology['arcs']):
            raise ValueError('Arc index out of range')
        if key not in cache:
            raw = topology['arcs'][key]
            if not isinstance(raw, list) or len(raw) < 2:
                raise ValueError('Arc needs at least two positions')
            result = []; x = y = 0
            for item in raw:
                px, py = position(item)
                if transform is not None:
                    if any(type(v) is not int for v in item):
                        raise ValueError('Quantized arc positions must be integers')
                    x += px; y += py
                    px, py = x * scale[0] + translate[0], y * scale[1] + translate[1]
                result.append(wgs84([px, py]))
            cache[key] = result
        return cache[key] if index >= 0 else list(reversed(cache[key]))

    def ring(indices):
        if not isinstance(indices, list) or not indices:
            raise ValueError('Ring needs arc indices')
        points = []
        for index in indices:
            part = arc(index)
            if points and points[-1] != part[0]:
                raise ValueError('Disconnected boundary arcs')
            points.extend(part if not points else part[1:])
        if len(points) < 4 or points[0] != points[-1] or len(set(points)) < 3:
            raise ValueError('Ring is unclosed or degenerate')
        if not sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:])):
            raise ValueError('Ring has zero area')
        return points

    districts = {}; seen = set()
    for geometry in collection['geometries']:
        code = geometry['properties']['district_id']
        if type(code) is not int or code <= 0 or str(code) in seen:
            raise ValueError('Missing, duplicate or invalid district ID')
        seen.add(str(code))
        if required_codes is not None and str(code) not in required_codes:
            continue
        kind = geometry['type']
        if kind not in ('Polygon', 'MultiPolygon'):
            raise ValueError('District must be Polygon or MultiPolygon')
        polygons = [geometry['arcs']] if kind == 'Polygon' else geometry['arcs']
        if not polygons or any(not polygon for polygon in polygons):
            raise ValueError('Empty district polygon')
        districts[str(code)] = [[ring(indices) for indices in polygon] for polygon in polygons]
    if not districts:
        raise ValueError('No districts to check')
    return districts


def ring_membership(point, ring):
    """Return inside, outside or boundary; ray crossing works for concave rings."""
    x, y = point; inside = False
    for (ax, ay), (bx, by) in zip(ring, ring[1:]):
        dx, dy = bx - ax, by - ay
        cross = (x - ax) * dy - (y - ay) * dx
        length = math.hypot(dx, dy)
        if (abs(cross) <= EPSILON * length and
                min(ax, bx) - EPSILON <= x <= max(ax, bx) + EPSILON and
                min(ay, by) - EPSILON <= y <= max(ay, by) + EPSILON):
            return 'boundary'
        if (ay > y) != (by > y) and x < ax + (y - ay) * dx / dy:
            inside = not inside
    return 'inside' if inside else 'outside'


def polygon_membership(point, polygons):
    boundary = False
    for rings in polygons:
        outer = ring_membership(point, rings[0])
        if outer == 'outside':
            continue
        holes = [ring_membership(point, hole) for hole in rings[1:]]
        if 'inside' in holes:
            continue
        if outer == 'boundary' or 'boundary' in holes:
            boundary = True
        else:
            return 'inside'
    return 'boundary' if boundary else 'outside'


def audit_boundaries(root, records):
    path = root / 'geometry.topo.json'
    if path.resolve() != root.resolve() / 'geometry.topo.json':
        raise ValueError('Boundary input must not be an external symlink')
    raw = path.read_bytes()
    topology = strict_json_loads(raw.decode('utf-8'))
    required_codes = {ref.get('code') for row in records if row['kind'] == 'location'
                      for ref in row.get('admin_refs', []) if ref.get('level') == 'district'}
    districts = decode_districts(topology, required_codes)
    errors = []; cache = {}; checked = 0; boundary = 0; codes = set()
    for row in records:
        if row['kind'] != 'location':
            continue
        try:
            if row['country_code'] != 'NP':
                raise ValueError('Non-Nepal location requires its declared country boundary; not checked here')
            if not row['geometry'] or row['geometry']['type'] != 'Point':
                raise ValueError('Only Point locations are supported by this boundary check')
            point = wgs84(row['geometry']['coordinates'])
            refs = [ref for ref in row['admin_refs'] if ref['level'] == 'district']
            if not refs:
                raise ValueError('Missing district boundary reference')
            for ref in refs:
                code = ref['code']
                if code not in districts or ref['boundary_reference'] != BOUNDARY_REFERENCE + code:
                    raise ValueError('Unknown or mismatched district boundary reference')
                key = (point, code)
                if key not in cache:
                    cache[key] = polygon_membership(point, districts[code])
                if cache[key] == 'outside':
                    raise ValueError('Point outside declared district ' + code)
                boundary += cache[key] == 'boundary'; codes.add(code)
            checked += 1
        except (ValueError, KeyError, TypeError) as error:
            errors.append(row['id'] + ': ' + str(error))
    if not checked:
        errors.append('No location passed the boundary check')
    return errors, {'location_records_checked': checked, 'district_polygons_loaded': len(districts),
                    'checked_district_codes': sorted(codes), 'distinct_point_district_checks': len(cache),
                    'boundary_hits': boundary, 'geometry_sha256': hashlib.sha256(raw).hexdigest(),
                    'boundary_epoch': 'unverified; repository display geometry'}
