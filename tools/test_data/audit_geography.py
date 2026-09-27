"""Validate stored geographic provenance against archived inputs, not live geography.

No network calls, coordinate generation, sampling-zone approval or historical
flood-boundary inference. Point/line archival equality does not prove that a
fictional report occurred there or satisfy terrain/boundary placement checks.
"""
import gzip
import hashlib
import json
import math
from pathlib import PurePosixPath
import re
from collections import Counter
from audit_contracts import shape_errors, utc

PROPERTIES='label feature_type historical_reference_ids source_url source_feature_id source_version source_license source_license_url use_conditions source_artifact_path source_artifact_sha256 country_codes coordinate_precision_m retrieved_at geometry_epoch uncertainty_m limitations'
MAX_ARCHIVE_BYTES=128*1024*1024


def positions(geometry):
    kind=geometry['type'];coords=geometry['coordinates']
    if kind=='Point':return [coords]
    if kind=='LineString':
        if len(coords)<2:raise ValueError('LineString needs two positions')
        return coords
    if kind=='MultiLineString':
        if not coords or any(len(line)<2 for line in coords):raise ValueError('MultiLineString contains an empty/short line')
        return [point for line in coords for point in line]
    raise ValueError('This archived-input checker only handles the supplied point/line context')


def source_geometry(feature,elements):
    refs=feature['properties']['source_feature_id'].split(',')
    if any(not re.fullmatch(r'(?:node|way)/[0-9]+',ref) for ref in refs):raise ValueError('Unsupported archived source feature ID')
    targets=[]
    for ref in refs:
        kind,number=ref.split('/');target=elements.get((kind,int(number)))
        if target is None:raise ValueError('Archived source feature missing: '+ref)
        targets.append(target)
    kind=feature['geometry']['type']
    if kind=='Point' and len(targets)==1 and targets[0]['type']=='node':
        return {'type':'Point','coordinates':[targets[0]['lon'],targets[0]['lat']]}
    if kind in ('LineString','MultiLineString') and all(target['type']=='way' for target in targets):
        lines=[[[point['lon'],point['lat']] for point in target['geometry']] for target in targets]
        if kind=='LineString' and len(lines)==1:return {'type':kind,'coordinates':lines[0]}
        if kind=='MultiLineString':return {'type':kind,'coordinates':lines}
    raise ValueError('Context geometry does not match its archived node/way type')


def audit_context(root,geography,historical_ids,dataset):
    root=root.resolve();allowed=root/'demo/datasets'/dataset/'context/geographic-inputs'
    errors=[];cache={};matched=0;source_refs=set()
    if geography.get('type')!='FeatureCollection':return ['Expected a FeatureCollection'],{}
    features=geography['features'];ids=[feature['id'] for feature in features]
    if ids!=sorted(set(ids)):errors.append('Context feature IDs must be unique and sorted')
    for feature in features:
        ident=feature['id'];props=feature['properties']
        problems=shape_errors(props,PROPERTIES)
        if problems:errors.append(ident+': '+'; '.join(problems));continue
        try:
            if feature['type']!='Feature' or not re.fullmatch(r'geo-\d{6}',ident):raise ValueError('Invalid feature type/ID')
            for point in positions(feature['geometry']):
                if len(point)!=2 or any(type(value) not in (int,float) or not math.isfinite(value) for value in point) or not -180<=point[0]<=180 or not -90<=point[1]<=90:
                    raise ValueError('Invalid WGS84 lon/lat position')
            if not set(props['historical_reference_ids'])<=historical_ids:raise ValueError('Unknown historical reference ID')
            utc(props['retrieved_at']);utc(props['source_version'])
            if props['geometry_epoch']!=props['source_version'][:10]:raise ValueError('Geometry epoch differs from archived source version')
            name=props['source_artifact_path'];relative=PurePosixPath(name);path=root/name
            if relative.is_absolute() or '..' in relative.parts or '\\' in name or not path.resolve().is_relative_to(allowed):raise ValueError('Geographic input path escapes approved archive root')
            if name not in cache:
                if path.stat().st_size>MAX_ARCHIVE_BYTES:raise ValueError('Compressed geographic input exceeds audit limit')
                raw=path.read_bytes()
                with gzip.open(path,'rb') as stream:decoded=stream.read(MAX_ARCHIVE_BYTES+1)
                if len(decoded)>MAX_ARCHIVE_BYTES:raise ValueError('Decompressed geographic input exceeds audit limit')
                archive=json.loads(decoded)
                elements={(item['type'],item['id']):item for item in archive['elements']}
                if len(elements)!=len(archive['elements']):raise ValueError('Archived OSM element IDs repeat')
                cache[name]=(hashlib.sha256(raw).hexdigest(),archive,elements)
            digest,archive,elements=cache[name]
            if digest!=props['source_artifact_sha256']:raise ValueError('Archived geographic input SHA-256 mismatch')
            if archive['osm3s']['timestamp_osm_base']!=props['source_version']:raise ValueError('Archived OSM timestamp differs from feature source version')
            if source_geometry(feature,elements)!=feature['geometry']:raise ValueError('Context coordinates differ from archived source geometry')
            matched+=1;source_refs.update(props['source_feature_id'].split(','))
        except (OSError,ValueError,KeyError,TypeError) as error:
            errors.append(ident+': '+str(error).replace(str(root),'<repo>'))
    return errors,{'context_features':len(features),'features_matching_archive':matched,
                   'preserved_archives':len(cache),'referenced_osm_nodes_or_ways':len(source_refs)}


def audit_location_anchors(records,geography):
    features={feature['id']:feature for feature in geography['features']};errors=[];points=[];locations=[]
    for row in records:
        if row['kind']!='location':continue
        locations.append(row)
        refs=row['coordinate_provenance']['context_feature_ids']
        if any(ident not in features for ident in refs):errors.append(row['id']+': missing context feature');continue
        if row['coordinate_method']=='settlement_anchor':
            candidates=[features[ident] for ident in refs if features[ident]['geometry']['type']=='Point']
            matches=[feature for feature in candidates if feature['geometry']==row['geometry']]
            if not matches:errors.append(row['id']+': anchor geometry differs from cited context point')
            if matches and not any(row['country_code'] in feature['properties']['country_codes'] for feature in matches):errors.append(row['id']+': declared country differs from cited context metadata')
        else:errors.append(row['id']+': placement method requires a separate approved-zone/terrain check')
        if row['geometry'] and row['geometry']['type']=='Point':points.append(tuple(row['geometry']['coordinates']))
    return errors,{'location_records':len(locations),'distinct_point_coordinates':len(set(points)),
                   'coordinate_methods':dict(Counter(row['coordinate_method'] for row in locations))}
