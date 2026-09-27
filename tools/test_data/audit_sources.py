"""Read-only raw-source integrity and envelope checks; no imports or repairs."""
import hashlib
import json
import re
from collections import defaultdict
from pathlib import PurePosixPath

from audit_contracts import shape_errors, reject_nonfinite

RAW_FIELDS = 'schema_version source_id report_reference publisher original_language published_time_text original_content entries'
ENTRY_FIELDS = 'subject_label assertion_text reported_time_text location_text'


def audit_sources(root, records, dataset):
    root = root.resolve()
    allowed = root / 'demo/datasets' / dataset / 'raw/reports'
    integrity, envelopes = [], []
    observed = {'sources_checked': 0, 'structured_sources': 0, 'text_sources': 0, 'claims_checked': 0}
    claims = defaultdict(list)
    for row in records:
        if row['kind'] == 'claim': claims[row['source_id']].append(row)
    for source in sorted((r for r in records if r['kind'] == 'source'), key=lambda r:r['id']):
        ident = source['id']; observed['sources_checked'] += 1
        path_value = source['raw_path']; path = PurePosixPath(path_value)
        extension = '.json' if source['raw_format'] == 'structured_json' else '.txt'
        expected = allowed / (ident + extension)
        if path.is_absolute() or '..' in path.parts or root / path_value != expected:
            integrity.append(ident + ': raw path must be its own source file under raw/reports'); continue
        target = root / path_value
        if not target.resolve().is_relative_to(allowed) or not target.resolve().is_relative_to(root):
            integrity.append(ident + ': raw path/symlink escapes approved root'); continue
        try:
            if not target.is_file(): raise ValueError('raw source is missing or not a regular file')
            payload = target.read_bytes()
            if hashlib.sha256(payload).hexdigest() != source['raw_sha256']:
                integrity.append(ident + ': raw SHA-256 mismatch')
            text = payload.decode('utf-8')
            if not text.strip(): integrity.append(ident + ': raw source is empty')
        except (OSError, ValueError) as error:
            integrity.append(ident + ': ' + str(error).replace(str(root), '<repo>')); continue
        source_claims = sorted(claims[ident], key=lambda r:r['id'])
        observed['claims_checked'] += len(source_claims)
        if source['raw_format'] == 'structured_json':
            observed['structured_sources'] += 1
            try:
                raw = json.loads(text, parse_constant=reject_nonfinite)
                problems = shape_errors(raw, RAW_FIELDS)
                if problems:
                    envelopes.append(ident + ': ' + '; '.join(problems)); continue
                for key, expected_value in [('schema_version','1.0'), ('source_id',ident), ('report_reference',source['report_reference']), ('publisher',source['publisher']), ('original_language',source['original_language']), ('published_time_text',source['published_at']['original_text'])]:
                    if raw[key] != expected_value: envelopes.append(ident + ': raw/catalog mismatch in ' + key)
                if not isinstance(raw['original_content'], str) or not raw['original_content'].strip():
                    envelopes.append(ident + ': original_content must be nonempty text'); continue
                entries = raw['entries']
                if not isinstance(entries, list) or len(entries) != len(source_claims):
                    envelopes.append(ident + ': entry count differs from normalized claim count'); continue
                for index, entry in enumerate(entries):
                    errors = shape_errors(entry, ENTRY_FIELDS)
                    if errors: envelopes.append(f'{ident}: entry {index}: ' + '; '.join(errors))
                for claim in source_claims:
                    provenance = claim['provenance']
                    locator = re.fullmatch(r'entries\[(\d+)\]', provenance['source_locator'])
                    if not locator or int(locator[1]) >= len(entries):
                        envelopes.append(claim['id'] + ': invalid raw entry locator'); continue
                    entry = entries[int(locator[1])]
                    if not isinstance(entry, dict) or entry.get('assertion_text') != claim['assertion']['text']:
                        envelopes.append(claim['id'] + ': assertion differs from located original entry')
                    if provenance['original_excerpt'] not in raw['original_content']:
                        envelopes.append(claim['id'] + ': excerpt absent from original_content')
            except (ValueError, TypeError, KeyError) as error:
                envelopes.append(ident + ': invalid raw JSON/envelope: ' + str(error)[:180])
        else:
            observed['text_sources'] += 1
            for claim in source_claims:
                if claim['provenance']['original_excerpt'] not in text:
                    envelopes.append(claim['id'] + ': excerpt absent from raw text')
    return integrity, envelopes, observed
