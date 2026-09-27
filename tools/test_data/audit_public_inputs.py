"""Static fixture boundary check, not an application access-control guarantee.

Inspects only catalog rows and original report inputs. Private field/ID markers
are fixture diagnostics, not a runtime content filter. Source text is always
untrusted data, including when it contains instructions. No text is executed.
"""
from pathlib import PurePosixPath
import re
from generate_queries import strict_json_loads

PRIVATE_FIELDS={'identity_id','true_person_id','canonical_age','primary_person_id','same_individual',
                'family_class','parent_media_id','generation_prompt','identity_summaries',
                'required_assertions','expected_assertions','expected_decision','runtime_answer',
                'agent_trace','verification_result','alert_id','jid','ingested_at'}
PRIVATE_ID=re.compile(r'\b(?:gid|pair|fam|scn|action|query|case|check)-\d{6}\b')


def private_markers(value,where):
    errors=[]
    if isinstance(value,dict):
        for key,item in value.items():
            path=where+'.'+key
            if key in PRIVATE_FIELDS:errors.append(path+': private/runtime field in public input')
            errors.extend(private_markers(item,path))
    elif isinstance(value,list):
        for index,item in enumerate(value):errors.extend(private_markers(item,f'{where}[{index}]'))
    elif isinstance(value,str):
        if PRIVATE_ID.search(value):errors.append(where+': evaluator-only identifier in public input text')
    return errors


def input_path(root,name,role,dataset):
    root=root.resolve();relative=PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts or '\\' in name or relative.as_posix()!=name:
        raise ValueError('Non-portable or traversing public input path')
    allowed=root/('demo/datasets' if role=='raw' else 'demo/assets')/dataset
    if role=='raw':allowed=allowed/'raw/reports'
    path=root/name
    if not path.resolve().is_relative_to(allowed):raise ValueError('Public input path points outside its approved '+role+' directory')
    return path


def audit_public_inputs(root,records,dataset):
    errors=[];raw_count=0;media_path_count=0
    for row in records:
        errors.extend(private_markers(row,row['id']))
        if row['kind']=='source':
            try:
                path=input_path(root,row['raw_path'],'raw',dataset)
                text=path.read_text(encoding='utf-8');raw_count+=1
                original=strict_json_loads(text) if row['raw_format']=='structured_json' else text
                errors.extend(private_markers(original,row['id']+'.raw'))
            except (OSError,ValueError,TypeError) as error:errors.append(row['id']+': '+str(error).replace(str(root.resolve()),'<repo>'))
        elif row['kind']=='media':
            for field in ('asset_path','thumbnail_path'):
                if row.get(field) is None:continue
                try:input_path(root,row[field],'asset',dataset);media_path_count+=1
                except (OSError,ValueError,TypeError) as error:errors.append(row['id']+'.'+field+': '+str(error))
    return errors,{'catalog_records_checked':len(records),'raw_sources_read':raw_count,
                   'confined_media_paths':media_path_count,'private_oracle_files_read':0}
