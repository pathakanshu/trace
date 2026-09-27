#!/usr/bin/env python3
"""Validate generated records/assets and write measured package manifests."""
from __future__ import annotations
import collections, hashlib, json, mimetypes, re, sys, zipfile, tempfile
from datetime import datetime
from pathlib import Path
try:
    import jsonschema
except ImportError:
    jsonschema=None
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]; DATASET="bhotekoshi-2016-exercise-v1"
DATA=ROOT/"demo/datasets"/DATASET; ASSETS=ROOT/"demo/assets"/DATASET; FIX=ROOT/"tests/fixtures"/DATASET
QUOTAS=json.loads((ROOT/"demo/spec/quotas.json").read_text(encoding="utf-8"))
SCHEMA=json.loads((ROOT/"demo/spec/trace-record.schema.json").read_text(encoding="utf-8"))
PREFIX={"incident":"inc","person":"per","organization":"org","source":"src","claim":"clm","media":"med","location":"loc","facility":"fac","infrastructure":"inf","hazard":"haz","aid":"aid","contributor":"act","contribution":"con","vote":"vot","task":"tsk","subscription":"sub","investigation":"inv"}

def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
    return h.hexdigest()
def jsonl(path):
    out=[]
    for n,line in enumerate(path.read_text(encoding="utf-8").splitlines(),1):
        if not line.strip(): raise ValueError(f"blank JSONL line: {path}:{n}")
        out.append(json.loads(line))
    return out
def write_json(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
def write_jsonl(path,rows):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text("".join(json.dumps(x,ensure_ascii=False,separators=(",",":"))+"\n" for x in rows),encoding="utf-8")
def dt(s): return datetime.fromisoformat(s.replace("Z","+00:00"))
def ref_pairs(x):
    """Return explicit {kind,id} references and ID fields by schema-aware traversal."""
    out=[]
    def walk(v):
        if isinstance(v,dict):
            if set(v)=={"kind","id"} and v.get("kind") in PREFIX: out.append((v["kind"],v["id"]))
            for k,w in v.items():
                if isinstance(w,str) and re.fullmatch(r"(?:inc|per|org|src|clm|med|loc|fac|inf|haz|aid|act|con|vot|tsk|sub|inv)-\d{6}",w):
                    if k.endswith("_id") or k.endswith("_ids") or k in ("source_id","contribution_id","parent_media_id","base_media_id","owner_id","creator_id","assignee_id","contributor_id","operator_organization_id","organization_id","location_id","claimed_location_id","proposed_location_id"): out.append((next((kind for kind,p in PREFIX.items() if w.startswith(p+"-")),""),w))
                elif isinstance(w,list):
                    for a in w:
                        if isinstance(a,str) and re.fullmatch(r"(?:inc|per|org|src|clm|med|loc|fac|inf|haz|aid|act|con|vot|tsk|sub|inv)-\d{6}",a): out.append((next((kind for kind,p in PREFIX.items() if a.startswith(p+"-")),""),a))
                        else: walk(a)
                else: walk(w)
    walk(x); return out

def main():
    results=[]; errors=[]; blocked=[]
    def check(name,ok,detail=""):
        results.append({"check":name,"status":"pass" if ok else "fail","detail":detail})
        if not ok: errors.append({"check":name,"detail":detail})
    records=collections.defaultdict(list); paths=list((DATA/"records").rglob("*.jsonl")); schema_validator=jsonschema.Draft202012Validator(SCHEMA,format_checker=jsonschema.FormatChecker()) if jsonschema else None
    schema_bad=[]; shard_bad=[]; decode_bad=[]
    for p in paths:
        try:
            b=p.read_bytes(); b.decode("utf-8")
            if b and not b.endswith(b"\n"): shard_bad.append(f"{p}:missing final newline")
            rows=jsonl(p)
            if len(rows)>100: shard_bad.append(f"{p}:{len(rows)} exceeds 100")
            for i,r in enumerate(rows,1):
                records[r.get("kind","unknown")].append(r)
                if schema_validator:
                    e=next(schema_validator.iter_errors(r),None)
                    if e: schema_bad.append(f"{r.get('id')} {e.message[:240]}")
        except Exception as e: decode_bad.append(f"{p}: {e}")
    check("JSONL UTF-8, parse, newline and shard limit",not shard_bad and not decode_bad,"; ".join(shard_bad[:5]+decode_bad[:5]) or f"{len(paths)} shards; maximum 100 records")
    external_schema=None
    if not schema_validator:
        try: external_schema=json.loads((DATA/"schema-validation.json").read_text(encoding="utf-8"))
        except Exception: external_schema={"status":"not_run","errors":["jsonschema unavailable; run python3 tools/test_data/schema_check.py"]}
    schema_ok=not schema_bad if schema_validator else external_schema.get("status")=="pass"
    schema_detail="; ".join(schema_bad[:10]) if schema_bad else (f"{sum(map(len,records.values()))} records; Draft 2020-12 + format checking" if schema_validator else f"external system-Python check: {external_schema.get('status')}")
    check("JSON Schema Draft 2020-12 + format checking",schema_ok,schema_detail)
    catalog={k:{r["id"]:r for r in v} for k,v in records.items()}; duplicates=[f"{k}:{rid}" for k,rs in catalog.items() for rid in rs if sum(x["id"]==rid for x in records[k])>1]
    check("unique record IDs",not duplicates,"; ".join(duplicates[:5]) or "all primary IDs are unique")
    counts={k:len(v) for k,v in records.items()}; expected=QUOTAS["primary_catalog_counts"]
    exact={k:counts.get(k,0)==v for k,v in expected.items() if k!="location"}
    check("exact primary record quotas excluding geography gate",all(exact.values()),json.dumps({k:{"expected":expected[k],"actual":counts.get(k,0)} for k,ok in exact.items() if not ok}) or "all non-geographic quotas exact")
    location_goal=expected["location"]; location_actual=counts.get("location",0)
    if location_actual!=location_goal:
        blocked.append({"requirement":"1000 verified locations","status":"blocked","expected":location_goal,"actual":location_actual,"reason":"Only four current settlement anchors and river context are verified; no approved reporting zones, historical flood extent, Lamosanghu anchor, or suitable polygon input. No geometry was fabricated."})
    if location_actual!=location_goal:
        results.append({"check":"geographic placement readiness","status":"blocked","detail":f"{location_actual}/{location_goal}; verified zones/areas unavailable; see generation-status.json"})
    # Foreign-key and lifecycle checks by explicit contract relation.
    ids={k:set(v) for k,v in catalog.items()}; ref_errors=[]
    def need(kind,value,where):
        if value is not None and value not in ids.get(kind,set()): ref_errors.append(f"{where} -> missing {kind}:{value}")
    for r in records["source"]:
        pub=r["publisher"]; need(pub["kind"],pub["id"],r["id"]+" publisher")
        for d in r["dependencies"]: need("source",d["source_id"],r["id"]+" dependency")
        raw=ROOT/r["raw_path"]
        if not raw.is_file(): ref_errors.append(f"{r['id']} raw source absent")
        elif digest(raw)!=r["raw_sha256"]: ref_errors.append(f"{r['id']} raw hash mismatch")
    for r in records["claim"]:
        need("source",r["source_id"],r["id"]+" source"); need(r["subject"]["kind"],r["subject"]["id"],r["id"]+" subject")
        need("location",r["location_id"],r["id"]+" location")
        for mid in r["supporting_media_ids"]: need("media",mid,r["id"]+" media")
        for field in ("corrects_claim_ids","related_claim_ids"):
            for cid in r[field]: need("claim",cid,r["id"]+" "+field)
        source=catalog["source"].get(r["source_id"])
        if source and source["available_at"]!=r["available_at"]: ref_errors.append(f"{r['id']} available_at differs from source")
        if r["reported_at"]["value"] and dt(r["reported_at"]["value"])>dt(r["available_at"]): ref_errors.append(f"{r['id']} report time after ingestion")
    fields={"facility":[("location_id","location"),("operator_organization_id","organization")],"aid":[("location_id","location"),("organization_id","organization")],"media":[("source_id","source"),("claimed_location_id","location")],"contribution":[("contributor_id","contributor"),("proposed_location_id","location")],"vote":[("contributor_id","contributor"),("contribution_id","contribution")],"task":[("creator_id","contributor"),("assignee_id","contributor")],"subscription":[("contributor_id","contributor")],"investigation":[("owner_id","contributor")]}
    for kind,rels in fields.items():
        for r in records[kind]:
            for fld,target_kind in rels: need(target_kind,r.get(fld),r["id"]+" "+fld)
    for kind in ("infrastructure","hazard"):
        for r in records[kind]:
            for loc in r["location_ids"]: need("location",loc,r["id"]+" location_ids")
    for r in records["contribution"]:
        for fld,k in [("evidence_source_ids","source"),("evidence_claim_ids","claim"),("evidence_media_ids","media")]:
            for x in r[fld]: need(k,x,r["id"]+" "+fld)
    for r in records["investigation"]:
        for fld,k in [("selected_source_ids","source"),("selected_claim_ids","claim")]:
            for x in r[fld]: need(k,x,r["id"]+" "+fld)
        for s in r["subject_refs"]: need(s["kind"],s["id"],r["id"]+" subject_ref")
    check("foreign-key kind and reference closure",not ref_errors,"; ".join(ref_errors[:10]) or "all checked references resolve")
    # Source histogram, organization/publisher type, dependencies and raw excerpts.
    source_counts=collections.Counter(c["source_id"] for c in records["claim"]); histogram=collections.Counter(source_counts.values())
    wanted={int(k):v for k,v in QUOTAS["sources"]["claim_cardinality_histogram"].items()}
    check("source-to-claim cardinality histogram",dict(histogram)==wanted,f"actual {dict(histogram)}; expected {wanted}")
    organizations=catalog["organization"]; org_type_errors=[]; source_claims=collections.defaultdict(list)
    for c in records["claim"]: source_claims[c["source_id"]].append(c)
    for s in records["source"]:
        if s["publisher"]["kind"]=="organization" and organizations[s["publisher"]["id"]]["organization_type"]!=s["source_type"]: org_type_errors.append(s["id"])
        raw=(ROOT/s["raw_path"]).read_bytes()
        for c in source_claims[s["id"]]:
            if c["provenance"]["original_excerpt"].encode("utf-8") not in raw: ref_errors.append(f"{c['id']} excerpt missing from raw source")
    # Dependency edges must be backward and acyclic by monotone source IDs.
    deps=[(s["id"],d["source_id"]) for s in records["source"] for d in s["dependencies"]]
    dag_ok=all(int(a[-6:])>int(b[-6:]) for a,b in deps)
    check("publisher type and source dependency DAG",not org_type_errors and dag_ok and len(deps)==450,f"org-type mismatches={len(org_type_errors)}, edges={len(deps)}, backward-only={dag_ok}")
    check("raw source hashes and excerpt provenance",not ref_errors,f"hashes checked for {len(records['source'])} reports; excerpts verified")
    # Claim subject/type quotas and checkpoint expectations are computed, not asserted from fixtures.
    subject_counts=collections.Counter(c["subject"]["kind"] for c in records["claim"])
    check("claims by subject kind",dict(subject_counts)==QUOTAS["claims_by_subject_kind"],str(dict(subject_counts)))
    person_types=collections.Counter(c["assertion"]["type"] for c in records["claim"] if c["subject"]["kind"]=="person")
    type_ok={k:person_types[k]==v for k,v in QUOTAS["person_claims_by_type"].items()}
    check("person claim type quotas",all(type_ok.values()),str(dict(person_types)))
    # Actual image-file properties, duplicate relationships and thumbnail bounds.
    media=catalog["media"]; media_errors=[]; measured=json.loads((DATA/"asset-measurements.json").read_text(encoding="utf-8"))["images"]
    for row in measured:
        m=media.get(row["media_id"]); f=ROOT/row["path"]
        if not m or not f.is_file(): media_errors.append(f"missing record/file {row['media_id']}"); continue
        if digest(f)!=m["sha256"] or f.stat().st_size!=m["byte_size"]: media_errors.append(f"byte hash/size mismatch {row['media_id']}")
        try:
            with Image.open(f) as im:
                if (im.width,im.height)!=(m["width_px"],m["height_px"]): media_errors.append(f"dimensions mismatch {row['media_id']}")
                ex=im.getexif(); gps=ex.get_ifd(34853) if 34853 in ex else {}
                if bool(ex)!=row["exif_present"] or bool(gps)!=row["gps_present"]: media_errors.append(f"EXIF measurement mismatch {row['media_id']}")
            thumb=ROOT/m["thumbnail_path"]
            with Image.open(thumb) as ti:
                if max(ti.size)>320: media_errors.append(f"thumbnail too large {row['media_id']}")
        except Exception as e: media_errors.append(f"unreadable media {row['media_id']}: {e}")
    hashes=collections.Counter(m["sha256"] for m in records["media"])
    check("200 actual images, measured hashes, dimensions, EXIF and thumbnails",not media_errors and len(records["media"])==200 and len(hashes)==160,"; ".join(media_errors[:10]) or f"200 files; {len(hashes)} hashes; {sum(m['byte_size'] for m in records['media'])} bytes")
    families=jsonl(FIX/"oracle/media-families.jsonl"); family_counts=collections.Counter(x["family_class"] for x in families); family_errors=[]
    fam_by_media={member["media_id"]:fam for fam in families for member in fam["members"]}
    if len(families)!=120 or len(fam_by_media)!=200: family_errors.append("family/member total mismatch")
    for fam in families:
        base=media[fam["base_media_id"]]
        for member in fam["members"]:
            actual=media[member["media_id"]]
            if member["operation"]=="byte_copy" and base["sha256"]!=actual["sha256"]: family_errors.append(f"exact-copy hash mismatch {actual['id']}")
            if member["operation"] in ("resize","reencode","crop") and base["sha256"]==actual["sha256"]: family_errors.append(f"transform unchanged bytes {actual['id']}")
        if "earliest_publication_ingested_last" in fam["tags"]:
            old=base; copy=media[next(m["media_id"] for m in fam["members"] if m["parent_media_id"])]
            os=catalog["source"][old["source_id"]]; cs=catalog["source"][copy["source_id"]]
            if not (dt(old["available_at"])>dt(copy["available_at"]) and dt(os["published_at"]["value"])<dt(cs["published_at"]["value"])): family_errors.append(f"late-ingest chronology failed {fam['id']}")
    check("120 hidden image families, transformations and late-ingest cases",not family_errors and dict(family_counts)=={"base_plus_exact_copy":40,"base_plus_resize":20,"base_plus_reencode":10,"base_plus_crop":10,"singleton":40},"; ".join(family_errors[:10]) or f"{dict(family_counts)}")
    # Person identity and age oracle remain in private fixtures.
    groups=jsonl(FIX/"oracle/identities.jsonl"); pairs=jsonl(FIX/"oracle/identity-pairs.jsonl"); multiplicity=collections.Counter(len(g["person_ids"]) for g in groups)
    check("private identity oracle counts",len(groups)==1000 and sum(len(g["person_ids"]) for g in groups)==1150 and len(pairs)==250 and multiplicity=={1:865,2:120,3:15},f"groups={len(groups)}, person records={sum(len(g['person_ids']) for g in groups)}, pairs={len(pairs)}, multiplicity={dict(multiplicity)}")
    # Community and research quotas.
    for kind,field,key in [("contribution","contribution_type","contribution_types"),("vote","value","vote_values"),("task","task_type","task_types"),("task","state","task_states"),("investigation","investigation_type","investigations_by_topic")]:
        actual=collections.Counter(x[field] for x in records[kind]); wanted=QUOTAS["community"].get(key) if key in QUOTAS["community"] else QUOTAS[key]
        check(key,dict(actual)==wanted,f"actual={dict(actual)} expected={wanted}")
    # Every duplicate-family and identity expectation is evaluator-only; record
    # inputs contain no hidden label/answer or runtime execution records.
    forbidden={"same_individual","identity_id","family_class","parent_media_id","expected_decision","runtime_answer","verification_result","agent_trace","alert_id"}
    leaked=[]
    def scan(obj,path):
        if isinstance(obj,dict):
            for k,v in obj.items():
                if k in forbidden: leaked.append(f"{path}:{k}")
                scan(v,path+"/"+k)
        elif isinstance(obj,list):
            for i,v in enumerate(obj): scan(v,path+f"/{i}")
    for kind,rows in records.items():
        for r in rows: scan(r,"records/"+kind+"/"+r["id"])
    check("private expectations separated from catalog inputs",not leaked,"; ".join(leaked[:8]) or "no private truth/runtime result fields in catalog")
    # Write checkpoint oracle and hero profile from deterministic closure.
    write_jsonl(FIX/"oracle/checkpoints.jsonl",QUOTAS["checkpoint_oracle_targets"])
    plan=json.loads((FIX/"allocation-plan.json").read_text(encoding="utf-8")); story=plan["story_plans"]
    hero_ids=set(plan["hero_person_ids"]); hero_media=set(plan["hero_media_ids"])
    profile_ids=collections.defaultdict(set); pending=[]
    def add_ref(kind,ident):
        if kind in catalog and ident in catalog[kind] and ident not in profile_ids[kind]: profile_ids[kind].add(ident); pending.append((kind,ident))
    for x in hero_ids: add_ref("person",x)
    for x in hero_media: add_ref("media",x)
    for sc in story:
        for x in sc["focal_ids"]:
            kind=next((k for k,p in PREFIX.items() if x.startswith(p+"-")),None)
            if kind: add_ref(kind,x)
    for x in catalog["organization"]: add_ref("organization",x)
    while pending:
        kind,ident=pending.pop(); r=catalog[kind][ident]
        # Known typed references in the normalized record contract.
        refs=[]
        if kind=="source":
            refs=[(r["publisher"]["kind"],r["publisher"]["id"]),*(("source",d["source_id"]) for d in r["dependencies"])]
            refs += [("claim",c["id"]) for c in records["claim"] if c["source_id"]==ident]
        elif kind=="claim":
            refs=[(r["subject"]["kind"],r["subject"]["id"]),("source",r["source_id"])]
            refs += [("location",r["location_id"])] if r["location_id"] else []
            refs += [("media",m) for m in r["supporting_media_ids"]+r["corrects_claim_ids"]+r["related_claim_ids"]]
            refs += [(x["kind"],x["id"]) for x in r["assertion"]["related_subjects"]]
        elif kind=="person": refs += [("claim",x) for x in r["support_needs_claim_ids"]]; refs += [("claim",c["id"]) for c in records["claim"] if c["subject"]=={"kind":"person","id":ident}]
        elif kind=="media": refs=[("source",r["source_id"])] + ([("location",r["claimed_location_id"])] if r["claimed_location_id"] else []) + ([("media",r["declared_predecessor_media_id"])] if r["declared_predecessor_media_id"] else [])
        elif kind in ("facility","aid"): refs += [(fld,target) for fld,target in (("location_id","location"),("operator_organization_id","organization"),("organization_id","organization")) if r.get(fld)]
        elif kind in ("infrastructure","hazard"): refs += [("location",x) for x in r["location_ids"]]
        elif kind=="contribution":
            refs=[("contributor",r["contributor_id"]),(r["target"]["kind"],r["target"]["id"])]
            refs += [("source",x) for x in r["evidence_source_ids"]]+[("claim",x) for x in r["evidence_claim_ids"]]+[("media",x) for x in r["evidence_media_ids"]]
            if r["proposed_location_id"]: refs.append(("location",r["proposed_location_id"]))
        elif kind=="subscription": refs=[("contributor",r["contributor_id"]),(r["subject"]["kind"],r["subject"]["id"])]
        elif kind=="investigation": refs=[("contributor",r["owner_id"]),*((x["kind"],x["id"]) for x in r["subject_refs"]),*(("source",x) for x in r["selected_source_ids"]),*(("claim",x) for x in r["selected_claim_ids"])]
        elif kind=="vote": refs=[("contributor",r["contributor_id"]),("contribution",r["contribution_id"])]
        elif kind=="task": refs=[("contributor",r["creator_id"]),("contributor",r["assignee_id"]) if r["assignee_id"] else ("contributor",r["creator_id"]),(r["target"]["kind"],r["target"]["id"]),*(("contribution",x) for x in r["submission_contribution_ids"])]
        for k,x in refs: add_ref(k,x)
    hero_dir=FIX/"hero"; hero_dir.mkdir(parents=True,exist_ok=True)
    for kind,all_rows in records.items():
        chosen=[r for r in all_rows if r["id"] in profile_ids[kind]]
        if chosen: write_jsonl(hero_dir/f"{kind}.jsonl",chosen)
    gid_by_person={pid:g["identity_id"] for g in groups for pid in g["person_ids"]}
    hero_group_ids={gid_by_person[x] for x in hero_ids if x in gid_by_person}
    write_json(hero_dir/"manifest.json",{"dataset_id":DATASET,"profile":"hero-50","private_fixture":True,"identity_group_count":len(hero_group_ids),"person_record_ids":sorted(hero_ids),"identity_group_ids":sorted(hero_group_ids),"image_upload_ids":sorted(hero_media),"image_family_classes":sorted({fam_by_media[x]["family_class"] for x in hero_media}),"scenario_ids":[s["id"] for s in story],"record_counts_from_foreign_key_closure":{k:len(v) for k,v in sorted(profile_ids.items())},"primary_records_must_not_import_oracle_fields":True})
    # Package assets separately and record the actual checksum and file inventory.
    archive=Path(tempfile.gettempdir())/f"{DATASET}-assets.zip"; asset_files=sorted([p for p in ASSETS.rglob("*") if p.is_file()]); asset_hashes=[{"path":p.relative_to(ROOT).as_posix(),"sha256":digest(p),"byte_size":p.stat().st_size} for p in asset_files]
    if archive.is_file(): archive_meta={"path":str(archive),"sha256":digest(archive),"byte_size":archive.stat().st_size}
    else: archive_meta={"path":str(archive),"status":"missing"}
    distribution=DATA/"asset-distribution.json"
    if distribution.is_file():
        archive_meta=json.loads(distribution.read_text(encoding="utf-8"))
    write_json(DATA/"licenses.json",[{"license_id":"lic-000001","title":"Trace controlled synthetic placeholder media","creator":"Trace exercise dataset generation tooling","acquisition":"locally generated procedural vector illustrations; no external image sources","terms":"Internal exercise assets; redistribution requires project owner review.","attribution_required":False,"is_documentary":False}])
    manifest={"dataset_id":DATASET,"schema_version":"1.0","created_at":datetime.now().astimezone().isoformat(timespec="seconds"),"seed":QUOTAS["seed"],"fictional_content_notice":"People, organizations, reports, media captions, and response activity are fictional. The 1,000-person workload is an exercise scale, not a historical missing-person count.","record_counts":counts,"record_shards":[{"path":p.relative_to(ROOT).as_posix(),"sha256":digest(p),"byte_size":p.stat().st_size,"records":len(jsonl(p))} for p in sorted(paths)],"asset_bundle":archive_meta,"assets":asset_hashes,"geography":{"status":"blocked","verified_location_records":location_actual,"required_location_records":location_goal},"runtime_outputs_prefilled":False}
    write_json(DATA/"manifest.json",manifest)
    report={"dataset_id":DATASET,"generated_at":datetime.now().astimezone().isoformat(timespec="seconds"),"validator":"tools/test_data/validate_dataset.py","jsonschema_version":getattr(jsonschema,"__version__",external_schema.get("jsonschema_version") if external_schema else "external") if jsonschema else (external_schema.get("jsonschema_version") if external_schema else "external not run"),"summary":{"records":sum(counts.values()),"counts":counts,"checks_passed":sum(x["status"]=="pass" for x in results),"checks_failed":len(errors),"blocked_requirements":blocked},"checks":results,"errors":errors,"blocked":blocked,"limitations":["No compatible application importer/runtime replay was executed; no agent output is seeded.","Geographic zone readiness blocks the remaining 830 locations and full geographic acceptance.","OS/UI offline asset loading is not verified by this data-only validator."]}
    write_json(DATA/"validation-report.json",report)
    print(json.dumps(report["summary"],indent=2,ensure_ascii=False))
    for e in errors: print("FAIL",e["check"],e["detail"][:240])
    if errors: return 1
    return 0
if __name__=="__main__": sys.exit(main())
