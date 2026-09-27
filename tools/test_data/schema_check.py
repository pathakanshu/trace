#!/usr/bin/env python3
"""Run Draft 2020-12 schema/format checks using a Python with jsonschema."""
import json, pathlib, sys
import jsonschema
ROOT=pathlib.Path(__file__).resolve().parents[2]; DATA=ROOT/"demo/datasets/bhotekoshi-2016-exercise-v1"
schema=json.loads((ROOT/"demo/spec/trace-record.schema.json").read_text(encoding="utf-8"))
validator=jsonschema.Draft202012Validator(schema,format_checker=jsonschema.FormatChecker())
checked=0; errors=[]
for path in sorted((DATA/"records").rglob("*.jsonl")):
    raw=path.read_bytes(); raw.decode("utf-8")
    for line_no,line in enumerate(raw.splitlines(),1):
        if not line.strip(): errors.append(f"{path}:{line_no}: blank line"); continue
        record=json.loads(line); checked+=1
        error=next(validator.iter_errors(record),None)
        if error: errors.append(f"{record.get('id')}: {error.message[:240]}")
        if len(errors)>=100: break
    if len(errors)>=100: break
report={"status":"pass" if not errors else "fail","validator":"jsonschema Draft202012Validator; FormatChecker enabled","jsonschema_version":jsonschema.__version__,"records_checked":checked,"errors":errors}
(DATA/"schema-validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report,indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
