#!/usr/bin/env python3
"""Generate Trace's deterministic fictional exercise catalog from reserved IDs.

The verified reporting-zone gate is enforced: only the 50 hero anchor points
and 120 shared sites are emitted. Other records are generated independently.
"""
from __future__ import annotations
import hashlib, json, random
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DATASET="bhotekoshi-2016-exercise-v1"
DATA=ROOT/"demo/datasets"/DATASET
FIX=ROOT/"tests/fixtures"/DATASET
ASSETS=ROOT/"demo/assets"/DATASET
START=datetime(2016,7,5,12,15,tzinfo=timezone.utc)
NOW=datetime.now(timezone.utc).replace(microsecond=0)
NOW_ISO=NOW.isoformat().replace("+00:00","Z")
SEED=20160705
P={"incident":"inc","person":"per","organization":"org","source":"src","claim":"clm","media":"med","location":"loc","facility":"fac","infrastructure":"inf","hazard":"haz","aid":"aid","contributor":"act","contribution":"con","vote":"vot","task":"tsk","subscription":"sub","investigation":"inv"}
FIRST=["Maya","Asha","Sita","Nirmala","Laxmi","Pema","Karma","Tsering","Dawa","Pasang","Bikash","Suman","Ramesh","Kiran","Anil","Sunita","Rita","Gita","Tara","Manisha","Prakash","Arjun","Nabin","Milan","Bimala","Sanjay","Hari","Deepa","Kusum","Saraswati","Raju","Indira"]
LAST=["Gurung","Tamang","Sherpa","Rai","Lama","Thapa","Shrestha","Karki","Adhikari","Magar","Bhandari","Khadka","Maharjan","Ghale","Malla","Basnet","Koirala","Poudel","Bista"]
FIRST_NE=["माया","आशा","सीता","निर्मला","लक्ष्मी","पेमा","कर्मा","छिरिङ","दावा","पासाङ","विकास","सुमन","रमेश","किरण","अनिल","सुनिता"]
LAST_NE=["गुरुङ","तामाङ","शेर्पा","राई","लामा","थापा","श्रेष्ठ","कार्की","अधिकारी","मगर","भण्डारी","खड्का"]
ANCHORS=[("Kodari",27.9646238,85.9568747,"geo-000002"),("Tatopani",27.9448408,85.9490115,"geo-000003"),("Bahrabise",27.787806,85.899582,"geo-000004"),("Khadichaur",27.7543053,85.8269035,"geo-000005")]

def rid(kind,n): return f"{P[kind]}-{n:06d}"
def utc(dt): return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00","Z")
def at(hour): return START+timedelta(hours=hour)
def tim(dt,precision="minute",original=None):
    if dt is None: return {"value":None,"date":None,"precision":"unknown","original_text":None,"timezone":None,"range_start":None,"range_end":None}
    return {"value":utc(dt),"date":None,"precision":precision,"original_text":original or dt.astimezone(timezone(timedelta(hours=5,minutes=45))).strftime("%Y-%m-%d %H:%M NPT"),"timezone":"Asia/Kathmandu","range_start":None,"range_end":None}
def common(kind,n,available,incident="inc-000001"):
    return {"schema_version":"1.0","dataset_id":DATASET,"id":rid(kind,n),"kind":kind,"incident_id":incident,"available_at":utc(available),"is_synthetic":True}
def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda:f.read(1024*1024),b""): h.update(c)
    return h.hexdigest()
def dump(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
def jsonl(path,items):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text("".join(json.dumps(x,ensure_ascii=False,separators=(",",":"))+"\n" for x in items),encoding="utf-8")
def read_jsonl(path): return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]

def load_plan(): return json.loads((FIX/"allocation-plan.json").read_text(encoding="utf-8"))
def source_release(n):
    return 6 if n<=150 else 12 if n<=1000 else 24 if n<=1200 else 36 if n<=1300 else 48 if n<=1400 else 72

def build_people(plan):
    rng=random.Random(SEED); groups=plan["identity_groups"]; person_records=[]; claims=[]; name_by_group={}
    # Ensure the 20 hero hard negatives share a plausible name and adult age.
    paired_names={}
    for i in range(20): paired_names[i+22]=i+2
    for gi,group in enumerate(groups,1):
        name="Maya Gurung" if gi==1 else f"{FIRST[(gi*7)%len(FIRST)]} {LAST[(gi*11)%len(LAST)]}"
        ne_name=f"{FIRST_NE[(gi*7)%len(FIRST_NE)]} {LAST_NE[(gi*11)%len(LAST_NE)]}"
        if gi in paired_names: name=name_by_group[paired_names[gi]][0]
        name_by_group[gi]=(name,ne_name)
        loc_id=rid("location",gi) if gi<=50 else None
        for member_no,pid in enumerate(group["person_ids"]):
            pn=int(pid.split("-")[1]); claim_id=rid("claim",pn)
            available=at(6) if gi<=300 and member_no==0 else at(12)
            age=group["canonical_age"]
            if age is not None and member_no==1 and gi%9==0: age=min(130,age+1)
            if age is not None and member_no==2 and gi%13==0: age=max(0,age-1)
            variants=[name]
            if member_no: variants += [f"{name.split()[0]} {name.split()[1][0]}.",f"{name.split()[1]} {name.split()[0]}"]
            elif gi%4==0: variants.append(ne_name)
            rec=common("person",pn,available)
            rec.update({"display_name":name if member_no==0 else variants[1],"name_variants":list(dict.fromkeys(variants)),"reported_age":age,
                "description":"Fictional record in a counterfactual response exercise; any personal details are attributed to a report and are not identity proof.","support_needs_claim_ids":[]})
            person_records.append(rec)
            loc=loc_id
            if loc is not None:
                anchor=ANCHORS[(gi-1)%len(ANCHORS)]
                summary=f"{name} is listed in this fictional exercise as not yet contacted; the report points to the named settlement anchor with a broad uncertainty radius."
            else:
                summary=f"{name} is listed in this fictional exercise as not yet contacted; no location is asserted in this report."
            claims.append({"id":claim_id,"kind":"person","subject":{"kind":"person","id":pid},"type":"MISSING","text":summary,
                "quantity":None,"unit":None,"reported_at":tim(at(5)),"location_id":loc,"supporting_media_ids":[],"corrects_claim_ids":[],"related_claim_ids":[],
                "availability":available,"planned_hour":6 if gi<=300 and member_no==0 else 12})
    return person_records,claims,groups

def build_locations(plan):
    locations=[]
    # Hero points repeat only the four verified settlement coordinates. They
    # are fictional observations with large uncertainty, never jittered.
    for n in range(1,51):
        name,lat,lon,feature=ANCHORS[(n-1)%4]
        rec=common("location",n,at(6))
        rec.update({"name":f"Fictional observation anchor {n:02d} — {name} Exercise","country_code":"NP",
          "admin_refs":[{"level":"district","code":"30","name":"Sindhupalchok","boundary_reference":"geometry.topo.json:districts/district_id=30","boundary_epoch":None}],
          "geometry":{"type":"Point","coordinates":[lon,lat]},"precision":"approximate_point","catalog_role":"initial_observation_point",
          "coordinate_method":"settlement_anchor","uncertainty_radius_m":1000,
          "coordinate_provenance":{"basis":"Fictional hero observation anchored at a currently mapped named settlement; broad uncertainty; no historical presence is asserted.",
            "historical_reference_ids":["hist-000001","hist-000002"],"context_feature_ids":[feature],"terrain_validation":"not_available"}})
        locations.append(rec)
    # Exact shared-site quota. IDs 841–960 are reserved for these sites.
    site_names=["triage table","shelter desk","supply ledger","road check","water point","meeting point","communications desk","intake table"]
    for off in range(120):
        n=841+off; name,lat,lon,feature=ANCHORS[off%4]
        rec=common("location",n,at(12))
        rec.update({"name":f"{name} {site_names[off%8]} Exercise {off+1:03d}","country_code":"NP",
          "admin_refs":[{"level":"district","code":"30","name":"Sindhupalchok","boundary_reference":"geometry.topo.json:districts/district_id=30","boundary_epoch":None}],
          "geometry":{"type":"Point","coordinates":[lon,lat]},"precision":"site","catalog_role":"shared_site","coordinate_method":"settlement_anchor","uncertainty_radius_m":1000,
          "coordinate_provenance":{"basis":"Fictional shared exercise site anchored at a currently mapped settlement point; not a real facility or event location.",
            "historical_reference_ids":["hist-000001","hist-000002"],"context_feature_ids":[feature],"terrain_validation":"not_available"}})
        locations.append(rec)
    return locations

def build_org_contributors():
    specs=[]
    specs.extend(("POLICE_RESCUE",x) for x in ["Valley Search Desk","Corridor Rescue Unit","North Checkpoint Team","River Watch Post","Family Liaison Desk","Access Response Unit"])
    specs.extend(("HOSPITAL",x) for x in ["Tatopani Intake Clinic","Bahrabise Health Post","Khadichaur Care Desk","Upper Corridor Medical Unit","Valley Referral Centre","Lamosanghu Intake Desk","Bridge-side Triage Room","Downstream Support Clinic"])
    specs.extend(("NGO",x) for x in ["Community Supply Circle","Shelter Support Group","Water and Hygiene Team","Family Reunification Desk","Access Support Network","Local Aid Collective","Volunteer Medical Desk","Household Support Group"])
    specs.extend(("GOVERNMENT",x) for x in ["District Coordination Cell","Municipal Information Desk","Road Status Office","Emergency Logistics Desk"])
    specs.extend(("COMMUNITY_NEWS",x) for x in ["Valley Community Bulletin","Bahrabise Noticeboard","Khadichaur Message Desk","Corridor Radio Exercise","Tatopani Community Notes","Riverbank Updates Group"])
    orgs=[]
    for n,(typ,name) in enumerate(specs,1):
        r=common("organization",n,at(6)); r.update({"name":f"{name} Exercise","organization_type":typ,"description":"Fictional institution for a controlled training exercise; not a real agency or service."}); orgs.append(r)
    roles=[["volunteer"],["researcher"],["reviewer"],["organization_operator"],["volunteer","researcher"],["volunteer","reviewer"]]
    contributors=[]
    langs=["ne","en","bo","zh","new","ta","hi"]
    for n in range(1,81):
        r=common("contributor",n,at(6)); lang=langs[(n-1)%len(langs)]; r.update({"display_name":f"Exercise Contributor {n:03d}","roles":roles[(n-1)%len(roles)],"languages":[lang] if lang=="en" else [lang,"en"]}); contributors.append(r)
    return orgs,contributors

def build_subjects():
    facilities=[]; ftypes=["TREATMENT"]*8+["SHELTER"]*12+["AID_DISTRIBUTION"]*8+["COORDINATION_COMMUNICATIONS"]*8
    for n,typ in enumerate(ftypes,1):
        r=common("facility",n,at(12)); r.update({"name":f"{typ.replace('_',' ').title()} Exercise Site {n:02d}","facility_type":typ,"location_id":rid("location",840+n),"operator_organization_id":rid("organization",7+(n%8))}); facilities.append(r)
    infra=[]; itypes=["ROAD_SEGMENT"]*10+["BRIDGE"]*8+["POWER"]*6+["WATER_COMMUNICATIONS"]*6
    for n,typ in enumerate(itypes,1):
        loc=876+n; r=common("infrastructure",n,at(12)); r.update({"name":f"{typ.replace('_',' ').title()} Exercise Subject {n:02d}","infrastructure_type":typ,"location_ids":[rid("location",loc),rid("location",loc+1)],"operator_organization_id":rid("organization",19+n%4)}); infra.append(r)
    hazards=[]; htypes=["FLOOD"]*8+["SLOPE_DEBRIS"]*6+["ACCESS_SECONDARY"]*4
    for n,typ in enumerate(htypes,1):
        loc=906+n; r=common("hazard",n,at(12)); r.update({"name":f"Reported {typ.replace('_',' ').lower()} Exercise Observation {n:02d}","hazard_type":typ,"location_ids":[rid("location",loc),rid("location",loc+1)]}); hazards.append(r)
    aids=[]; atypes=["NEED"]*20+["OFFER"]*12+["DELIVERY"]*8
    for n,typ in enumerate(atypes,1):
        loc=925+((n-1)%36); r=common("aid",n,at(12)); r.update({"name":f"{typ.title()} Exercise Entry {n:02d}","aid_type":typ,"location_id":rid("location",loc),"organization_id":rid("organization",15+n%8)}); aids.append(r)
    return facilities,infra,hazards,aids

def assertion(typ,text,quantity=None,unit=None,related=None):
    return {"type":typ,"text":text,"quantity":quantity,"unit":unit,"related_subjects":related or []}

def build_claims_and_sources(plan, groups, facilities, infrastructure, hazards, aids, media_rows, people):
    # Keep all reserved source cardinalities; every report remains fictional.
    allocation=plan["source_claim_allocations"]
    report_claims={sid:a["claim_ids"] for sid,a in allocation.items()}
    claim_source=plan["claim_to_source"]
    claim_defs={}
    person_names={p["id"]:p["display_name"] for p in people}
    def add(cid,subject,typ,text,reported,location=None,media=None,related=None,q=None,u=None):
        claim_defs[cid]={"subject":subject,"type":typ,"text":text,"reported":reported,"location":location,"media":media or [],"related":related or [],"quantity":q,"unit":u}
    by_person={g["primary_person_id"]:g for g in groups}
    # Initial missing claims were allocated first and are available exactly at
    # their source's exercise-clock release.
    for g in groups:
        for j,pid in enumerate(g["person_ids"]):
            cid=rid("claim",int(pid[-6:])); release=source_release(int(claim_source[cid][-6:]))
            name=person_names[pid]; wordings=[f"Fictional family-liaison intake lists {name} as not yet contacted; the time of last contact was not supplied.",f"An exercise volunteer relay says relatives have not checked in with {name}. No outcome is reported.",f"The synthetic intake ledger keeps an open contact request for {name}; this is not a historical case or identity finding.",f"Fictional caller note: the household has not re-established contact with {name}; last-known place remains unreported."]
            add(cid,{"kind":"person","id":pid},"MISSING",wordings[(int(pid[-6:])-1)%len(wordings)],at(max(0,release-1)),rid("location",int(g["identity_id"][-6:])) if g["hero"] else None)
    # The final identity cohort is built as sourced, attributed report claims.
    # Report timing order yields the quota checkpoint counts; disputed cases
    # preserve both opposing claims and are never resolved here.
    future=[]
    def person_claim(gid,typ,reported_hour,release_min=72,txt=None):
        future.append((gid,typ,reported_hour,release_min,txt))
    # Safe primary outcomes: 250 people, staged 100/60/50/40 by T+24/36/48/72.
    for lo,hi,h in [(1,100,24),(101,160,36),(161,210,48),(211,250,72)]:
        for gid in range(lo,hi+1): person_claim(gid,"FOUND_SAFE",h-1,h)
    # Injured cohort, staged 20/20/10; the last 150 claims are additional
    # follow-up reports for already represented people.
    for lo,hi,h in [(701,720,24),(721,740,36),(741,750,48)]:
        for gid in range(lo,hi+1): person_claim(gid,"INJURED",h-1,h)
    # First 25 opposing pairs have equal known times; the other 25 have
    # unknown times. Their availability follows the replay checkpoint schedule.
    for gid in range(951,1001):
        rel=24 if gid<=980 else 36 if gid<=990 else 48
        rh=None if gid>=976 else rel-1
        person_claim(gid,"FOUND_SAFE",rh,rel,"Competing fictional report says contacted safely; conflict intentionally retained.")
        person_claim(gid,"MISSING",rh,rel,"Competing fictional report still lists person missing; conflict intentionally retained.")
    for gid in range(951,961):
        rel=24 if gid<=954 else 36 if gid<=957 else 48
        person_claim(gid,"DECEASED",rel-1,rel,"Unverified fictional rumor only; never a determination.")
    # Additional report depth to exact type quotas: 300 safe, 150 injured,
    # 100 stale missing, 550 sightings, 140 details.
    for i in range(300): person_claim(1+i if i<3 else 251+(i%450),"FOUND_SAFE",71,72)
    for i in range(150): person_claim(701+(i%50),"INJURED",71,72)
    for i in range(100): person_claim(1+(i%100),"MISSING",15,72,"Earlier fictional missing report retained as historical source history.")
    # Fill the 24/36/48-hour source batches with neutral observations so
    # downstream source availability never precedes a reported time.
    filler_i=0
    for release,count in [(24,16),(36,97),(48,117)]:
        for i in range(count):
            typ="SEEN_AT_LOCATION" if filler_i%2==0 else "PERSON_DETAIL"; filler_i+=1
            person_claim(1+((release+i)%1000),typ,release-1,release)
    for i in range(550-115): person_claim(1+(i%1000),"SEEN_AT_LOCATION",60+(i%10),72)
    for i in range(140-115): person_claim(1+(i%1000),"PERSON_DETAIL",60+(i%10),72)
    future.sort(key=lambda x:(x[3],0 if groups[x[0]-1]["hero"] else 1,x[2] if x[2] is not None else 100))
    assert {h:sum(1 for x in future if x[3]==h) for h in (24,36,48,72)}=={24:200,36:200,48:200,72:1050}
    assert len(future)==1650
    for i,(gid,typ,rh,rel,txt) in enumerate(future,1301):
        g=groups[gid-1]; pid=g["primary_person_id"]; name=person_names[pid]; cid=rid("claim",i)
        templates={
          "FOUND_SAFE": [f"A fictional response-desk entry says {name} checked in safely; this report alone does not resolve identity.",f"Synthetic family-liaison note reports contact with {name} and says no immediate help was requested.",f"An exercise intake sheet lists {name} as reached. Original source history remains attached; this is not a verified result."],
          "INJURED": [f"A fictional treatment-desk report says {name} requested care; the severity and follow-up remain unknown.",f"Synthetic clinic intake records a reported injury for {name}; no diagnosis or identity confirmation is asserted."],
          "MISSING": [f"Earlier exercise family-liaison report still lists {name} as not contacted; retain it alongside later reports.",f"A fictional volunteer ledger repeats an open contact request for {name}; this older report does not override newer evidence."],
          "SEEN_AT_LOCATION": [f"A single synthetic volunteer note reports seeing {name} near an exercise site; this sighting is uncorroborated.",f"Fictional field log says {name} was seen near a named exercise anchor; time and identity remain report claims.",f"One exercise contributor reports a possible sighting of {name}; no independent confirmation is included."],
          "PERSON_DETAIL": [f"A fictional household description for {name} mentions a blue outer layer; clothing is not identity proof.",f"Synthetic intake note for {name} records a dark bag among reported belongings; detail remains unattributed evidence.",f"An exercise caller describes {name} as carrying a small pack; description may be incomplete or shared by others."],
          "DECEASED": [f"Unverified fictional rumor mentions {name}; no confirmation, identification, or determination is present."]}
        text=txt or templates[typ][(i+gid)%len(templates[typ])]
        loc=(rid("location",gid) if gid<=50 else rid("location",841+((gid-1)%120))) if typ=="SEEN_AT_LOCATION" else (rid("location",gid) if gid<=50 else None)
        add(cid,{"kind":"person","id":pid},typ,text,at(rh) if rh is not None else None,loc)
    # Media claims. 150 claims cite all 200 uploads: 100 singles, 50 doubles.
    # Exactly 60 claims cite >=2 uploads; infrastructure observations supply
    # the additional ten multi-upload claims.
    media_ids=[r["id"] for r in media_rows]
    media_claim_media=[]
    for i in range(150):
        mids=[media_ids[i]] if i<100 else media_ids[100+(i-100)*2:102+(i-100)*2]
        media_claim_media.append(mids)
        add(rid("claim",1151+i),{"kind":"media","id":mids[0]},"CAPTION_CONTEXT_CLAIM",f"Exercise publication records caption/context claim for {', '.join(mids)}; these labeled placeholder images are not documentary evidence.",at(20),media=mids)
    # 650 other-subject claims: exactly the contract's type totals.
    other=[]
    def emit(subject,typ,text,loc=None,related=None,q=None,u=None): other.append((subject,typ,text,loc,related,q,u))
    for i in range(200):
        r=infrastructure[i%len(infrastructure)]; emit({"kind":"infrastructure","id":r["id"]},"ACCESS_BLOCKED" if i%2==0 else "INSPECTION_REQUIRED",f"Exercise access desk report {i+1:03d} lists this fictional {r['infrastructure_type'].lower()} subject for follow-up; status is not historically verified.",r["location_ids"][0])
    for i in range(150):
        r=hazards[i%len(hazards)]; emit({"kind":"hazard","id":r["id"]},"HAZARD_REPORTED",f"Exercise observation {i+1:03d} records a fictional {r['hazard_type'].lower()} report at a named anchor; it is not a flood boundary.",r["location_ids"][0])
    for i in range(150):
        r=aids[i%len(aids)]; emit({"kind":"aid","id":r["id"]},["AID_NEEDED","AID_OFFERED","AID_DELIVERED"][i%3],f"Exercise aid ledger line {i+1:03d} reports 5 items for this fictional {r['aid_type'].lower()} entry; stock and delivery remain unverified.",r["location_id"],q=5,u="items")
    for i in range(100):
        r=facilities[i%len(facilities)]; emit({"kind":"facility","id":r["id"]},"FACILITY_CAPACITY" if i%2==0 else "FACILITY_SERVICE",f"Fictional exercise report {i+1:03d} lists a {12 if i%2==0 else 5} {'beds' if i%2==0 else 'items'} entry for this {r['facility_type'].lower()} scenario site; this is not a real facility.",r["location_id"],q=12 if i%2==0 else 5,u="beds" if i%2==0 else "items")
    for i in range(50): emit({"kind":"organization","id":rid("organization",i%32+1)},"ORG_SERVICE_AVAILABLE",f"Synthetic organization bulletin {i+1:03d} describes an exercise-only contact window; no real service or contact point is offered.")
    assert len(other)==650
    for i,(subject,typ,txt,loc,related,q,u) in enumerate(other,2951):
        # Ten infrastructure claims cite two uploads to meet the corpus-wide
        # multi-upload evidence threshold without inflating media claim count.
        mids=media_ids[(i-2951)*2:(i-2951)*2+2] if i<2961 else []
        add(rid("claim",i),subject,typ,txt,at(18),loc,mids,related,q,u)
    # Bind claims to their reserved source. Original text is repeated verbatim
    # in the source artifact and claim provenance for deterministic checking.
    from collections import defaultdict
    claims=[]; source_claim_bodies=defaultdict(list)
    for no in range(1,3601):
        cid=rid("claim",no); d=claim_defs[cid]; sid=claim_source[cid]
        available=at(source_release(int(sid[-6:])))
        excerpt=d["text"]
        claim={**common("claim",no,available),"source_id":sid,"subject":d["subject"],
          "assertion":assertion(d["type"],d["text"],d["quantity"],d["unit"],d["related"]),
          "reported_at":tim(d["reported"]),"provenance":{"extraction_method":"fixture_authored","original_excerpt":excerpt,"source_locator":f"record:{cid}"},
          "location_id":d["location"],"supporting_media_ids":d["media"],"corrects_claim_ids":[],"related_claim_ids":[]}
        claims.append(claim); source_claim_bodies[sid].append({"claim_id":cid,"excerpt":excerpt})
    # Source artifacts carry only asserted report content; metadata remains
    # synthetic and no agent outcome is prefilled.
    source_records=[]; sources_by_id={}
    # Declare exactly 450 relays only when an earlier immutable Source has a
    # claim about the same subject. Point them to independent predecessors so
    # the dependency graph remains shallow and does not widen profile closure.
    seen_subject_sources=defaultdict(list); dependency_by_source={}
    for sn in range(1,1801):
        sid=rid("source",sn); claim_ids=allocation[sid]["claim_ids"]
        if sn>=1001 and len(dependency_by_source)<450:
            for cid in claim_ids:
                d=claim_defs[cid]; key=(d["subject"]["kind"],d["subject"]["id"])
                candidates=[p for p in seen_subject_sources[key] if source_release(p)<=source_release(sn) and p not in dependency_by_source]
                if candidates:
                    dependency_by_source[sn]=max(candidates); break
        for cid in claim_ids:
            d=claim_defs[cid]; seen_subject_sources[(d["subject"]["kind"],d["subject"]["id"])].append(sn)
    assert len(dependency_by_source)==450
    for sn in range(1,1801):
        sid=rid("source",sn); spec=allocation[sid]; release=source_release(sn)
        publisher=spec["publisher"]; kind=publisher["kind"]
        org_types=["POLICE_RESCUE"]*6+["HOSPITAL"]*8+["NGO"]*8+["GOVERNMENT"]*4+["COMMUNITY_NEWS"]*6
        typ="INDIVIDUAL" if kind=="contributor" else org_types[int(publisher["id"][-6:])-1]
        dep=[{"source_id":rid("source",dependency_by_source[sn]),"relationship":"relays"}] if sn in dependency_by_source else []
        fmt="structured_json" if sn<=1260 else "pasted_text"
        relpath=f"demo/datasets/{DATASET}/raw/reports/{sid}."+("json" if fmt=="structured_json" else "txt")
        body=source_claim_bodies[sid]
        raw={"fictional_exercise_record":True,"source_id":sid,"title":f"Exercise report {sn:04d}","claims":body}
        rawbytes=(json.dumps(raw,ensure_ascii=False,indent=2)+"\n").encode() if fmt=="structured_json" else (f"FICTIONAL EXERCISE REPORT {sid}\n"+"\n".join(x["excerpt"] for x in body)+"\n").encode()
        rawpath=ROOT/relpath; rawpath.parent.mkdir(parents=True,exist_ok=True); rawpath.write_bytes(rawbytes)
        old_claims=set(plan.get("late_ingest_media_claim_ids",[])); old_sources={claim_source[c] for c in old_claims}
        pub_hour=20 if sid in old_sources else max(0,release-1)
        rec={**common("source",sn,at(release)),"title":raw["title"],"publisher":publisher,"source_type":typ,
          "report_reference":f"EXERCISE-{sn:04d}","published_at":tim(at(pub_hour)),"original_language":"en",
          "raw_format":fmt,"raw_path":relpath,"raw_sha256":hashlib.sha256(rawbytes).hexdigest(),"dependencies":dep,
          "dependency_disclosure":"declared" if dep else "no_dependency_declared"}
        source_records.append(rec); sources_by_id[sid]=rec
    return claims,source_records,sources_by_id

def build_media(sources_by_id,claims):
    measurements=json.loads((DATA/"asset-measurements.json").read_text(encoding="utf-8"))["images"]
    claim_for={mid:c for c in claims if c["subject"]["kind"]=="media" for mid in c["supporting_media_ids"]}
    rows=[]
    for ix,m in enumerate(measurements,1):
        cid=claim_for[m["media_id"]]; source=sources_by_id[cid["source_id"]]
        fname=Path(m["path"]).name
        rec=common("media",ix,datetime.fromisoformat(source["available_at"].replace("Z","+00:00")))
        caption=f"Synthetic exercise image {ix:03d}; fictional caption and scene."
        if 1<=ix<=12: caption=f"Synthetic exercise caption proposes {ANCHORS[ix%4][0]}, which conflicts with controlled metadata on some assets; unverified."
        if 121<=ix<=130: caption=f"Synthetic exercise caption on copy {ix:03d} proposes a different scene context; unverified."
        if 161<=ix<=170: caption=f"Synthetic exercise caption on resized copy {ix:03d} proposes a different scene context; unverified."
        rec.update({"media_type":"image","source_id":source["id"],"description":"Locally generated, clearly labeled fictional placeholder illustration; not documentary imagery.",
          "published_caption":caption,"reported_capture_time":tim(None),"claimed_location_id":None,
          "asset_path":f"demo/assets/{DATASET}/images/{fname}","sha256":m["sha256"],"byte_size":m["byte_size"],"mime_type":m["mime_type"],"width_px":m["width_px"],"height_px":m["height_px"],
          "duration_seconds":None,"actual_created_at":NOW_ISO,"license_id":"lic-000001","is_controlled_exercise_asset":True,
          "embedded_metadata_is_synthetic":True,"thumbnail_path":f"demo/assets/{DATASET}/thumbnails/{Path(fname).stem}.webp","declared_predecessor_media_id":None,"frame_origin":None})
        rows.append(rec)
    return rows

def build_community(contributors,claim_source,media_source):
    types=[t for t,n in [("COMMENT",70),("CORRECTION",30),("TRANSLATION",30),("GEOLOCATION",40),("EARLIER_COPY",25),("SOURCE_CITATION",25),("CHALLENGE",20)] for _ in range(n)]
    contributions=[]
    for i,typ in enumerate(types,1):
        lang="ne" if i<=40 else "en"; c=common("contribution",i,at(24+i%48)); target={"kind":"claim","id":rid("claim",1+(i-1)%3600)}
        nepali="यो अभ्यास रेकर्ड काल्पनिक हो; वास्तविक व्यक्ति वा घटनाको विवरण होइन।"
        body=nepali if lang=="ne" or typ=="TRANSLATION" else f"Fictional community {typ.lower()} contribution {i:03d}; no verification result is asserted."
        english=f"This exercise record is fictional; it describes no real person or event." if lang=="ne" or typ=="TRANSLATION" else None
        target={"kind":"media","id":rid("media",i-69)} if typ=="GEOLOCATION" else target
        media_evidence=[target["id"]] if target["kind"]=="media" else []
        evidence_source=media_source[target["id"]] if target["kind"]=="media" else claim_source[target["id"]]
        c.update({"contribution_type":typ,"contributor_id":rid("contributor",1+(i-1)%80),"target":target,"body":body,"language":"ne" if typ=="TRANSLATION" else lang,"english_rendering":english,
          "public_display":"anonymous" if i<=60 else "pseudonym","submitted_at":utc(at(24+i%48)),"evidence_source_ids":[evidence_source],
          "evidence_claim_ids":[target["id"]] if target["kind"]=="claim" else [],"evidence_media_ids":media_evidence,"proposed_location_id":rid("location",1+(i-1)%50) if typ=="GEOLOCATION" else None,
          "proposal_basis":"synthetic scenario proposal; requires review" if typ=="GEOLOCATION" else None,"translation_of":target if typ=="TRANSLATION" else None,
          "translation_method":"machine" if typ=="TRANSLATION" else None,"translation_review":None})
        contributions.append(c)
    values=["HELPFUL"]*240+["NOT_HELPFUL"]*120; votes=[]
    for i,val in enumerate(values,1):
        r=common("vote",i,at(30+i%42)); r.update({"contributor_id":rid("contributor",1+(i-1)%80),"contribution_id":rid("contribution",1+(i-1)%240),"value":val,"voted_at":utc(at(30+i%42))}); votes.append(r)
    types4=["GEOLOCATE","TRANSLATE","FIND_EARLIER_COPY","SOURCE_OR_CHALLENGE"]
    states=["OPEN"]*40+["IN_PROGRESS"]*20+["SUBMITTED"]*24+["REVIEWED"]*12; tasks=[]
    for i,state in enumerate(states,1):
        typ=types4[(i-1)%4]; cids=[rid("contribution",i)] if state in ("SUBMITTED","REVIEWED") else []
        r=common("task",i,at(30+i%42)); r.update({"task_type":typ,"title":f"Exercise {typ.lower()} task {i:03d}","target":{"kind":"media","id":rid("media",1+(i-1)%200)},"creator_id":rid("contributor",1+(i-1)%80),
          "assignee_id":rid("contributor",1+(i%80)) if state!="OPEN" else None,"state":state,"created_at":utc(at(24+i%20)),"updated_at":utc(at(30+i%42)),"submission_contribution_ids":cids,
          "review":{"contributor_id":rid("contributor",1+(i%80)),"reviewed_at":utc(at(30+i%42)),"note":"Synthetic workflow seed only; no truth, identity, or evidence verification result is asserted.","evidence_claim_ids":[]} if state=="REVIEWED" else None}); tasks.append(r)
    return contributions,votes,tasks

def build_followups():
    subjects=[("person",100),("location",20),("media",10),("incident",10),("organization",10)]; subs=[]; no=1
    for kind,count in subjects:
        limit={"person":1150,"location":1000,"media":200,"incident":1,"organization":32}[kind]
        for i in range(count):
            r=common("subscription",no,at(12)); r.update({"contributor_id":rid("contributor",1+(no-1)%80),"subject":{"kind":kind,"id":rid(kind,1+i%limit)},"created_at":utc(at(12)),"delivery":"in_app","active":True,"event_types":["new_claim","status_change"]}); subs.append(r); no+=1
    types=["PERSON_TIMELINE","ACCESS_HAZARD","AID_FACILITY","MEDIA_LINEAGE"]; investigations=[]
    for i in range(24):
        n=i+1; typ=types[i%4]; selected_claims=[rid("claim",1+i),rid("claim",1151+i)]
        r=common("investigation",n,at(72)); r.update({"owner_id":rid("contributor",1+i%80),"investigation_type":typ,"title":f"Saved exercise investigation {n:02d}",
          "query":"Compare the cited fictional reports and describe what remains unknown.","subject_refs":[{"kind":"person","id":rid("person",1+i)}],"selected_source_ids":[rid("source",1+i),rid("source",1001+i)],
          "selected_claim_ids":selected_claims,"gaps":["No application-generated agent result is included."],"time_cutoff":utc(at(72)),"saved_at":utc(at(72))}); investigations.append(r)
    return subs,investigations

def write_shards(records):
    root=DATA/"records"
    for kind,rows in records.items():
        folder=root/kind; folder.mkdir(parents=True,exist_ok=True)
        for old in folder.glob("part-*.jsonl"): old.unlink()
        for part,start in enumerate(range(0,len(rows),100),1):
            jsonl(folder/f"part-{part:04d}.jsonl",rows[start:start+100])

def main():
    plan=load_plan(); people,initial,groups=build_people(plan)
    locations=build_locations(plan); organizations,contributors=build_org_contributors()
    facilities,infrastructure,hazards,aids=build_subjects()
    # A stable media skeleton supplies measured bytes, but media records need
    # their source claim's release time. Construct source/claim records first.
    measurements=json.loads((DATA/"asset-measurements.json").read_text(encoding="utf-8"))["images"]
    media_skeleton=[{"id":x["media_id"]} for x in measurements]
    claims,sources,sources_by_id=build_claims_and_sources(plan,groups,facilities,infrastructure,hazards,aids,media_skeleton,people)
    media=build_media(sources_by_id,claims)
    # Claims reference their assigned subjects; organizations are attributed
    # through the publisher on each immutable Source.
    claim_source_map={c["id"]:c["source_id"] for c in claims}; media_source_map={m["id"]:m["source_id"] for m in media}
    contributions,votes,tasks=build_community(contributors,claim_source_map,media_source_map)
    subscriptions,investigations=build_followups()
    event=common("incident",1,at(0)); event_time=tim(None); event_time.update({"date":"2016-07-05","precision":"night","original_text":"Night of 5 July 2016 local time","timezone":"Asia/Kathmandu"})
    event.update({"name":"5 July 2016 Bhote Koshi flood response exercise","description":"Historical context: the night of 5 July 2016 Bhote Koshi flood in Sindhupalchok. This is a counterfactual software exercise: every person, report, institution, response action, and media item is fictional. The 1,000-person workload is a test scale, not a historical missing-person count.","event_time":event_time,"exercise_clock_start":utc(START),"display_timezone":"Asia/Kathmandu","historical_reference_ids":[f"hist-{i:06d}" for i in range(1,5)]})
    # Associate each Person record's initial claim with the exact release time
    # and keep public identity descriptions explicitly fictional.
    cmap={x["id"]:x for x in claims}
    for p in people: p["available_at"]=cmap[rid("claim",int(p["id"][-6:]))]["available_at"]
    all_records={"incident":[event],"person":people,"organization":organizations,"source":sources,"claim":claims,"media":media,
      "location":locations,"facility":facilities,"infrastructure":infrastructure,"hazard":hazards,"aid":aids,"contributor":contributors,
      "contribution":contributions,"vote":votes,"task":tasks,"subscription":subscriptions,"investigation":investigations}
    write_shards(all_records)
    # Public replay/query plans contain only scenarios, prompts and actions.
    # They never contain successful candidates, signals, alerts or traces.
    replay=FIX/"replay"; replay.mkdir(parents=True,exist_ok=True)
    jsonl(replay/"scenarios.jsonl",[{**s,"expected_runtime_outputs":[],"runtime_outputs_must_be_generated_by_application":True} for s in plan["story_plans"]])
    pairs=read_jsonl(FIX/"oracle/identity-pairs.jsonl"); actions=[]
    for i,pair in enumerate(pairs[:80]+pairs[165:185],1):
        actions.append({"action_id":f"act-{i:06d}","action":"human_review_required","person_a_id":pair["person_a_id"],"person_b_id":pair["person_b_id"],"expected_decision":"confirm_same_individual" if pair["same_individual"] else "reject_match","evidence_claim_ids":pair["evidence_claim_ids"],"generated_result":False})
    jsonl(replay/"actions.jsonl",actions)
    qtypes=["PERSON_CHANGE"]*10+["GEOGRAPHIC_ACCESS"]*8+["AID_FACILITY"]*8+["MEDIA_LINEAGE"]*8+["INSUFFICIENT_EVIDENCE"]*6
    jsonl(FIX/"queries.jsonl",[{"query_id":f"qry-{i:06d}","query_type":t,"prompt":"Answer from cited exercise sources, distinguish unknowns, and do not infer verification.","expected_evidence_ids":[],"expected_limitations":["Application must generate answer and trace at runtime."],"runtime_answer":None} for i,t in enumerate(qtypes,1)])
    cats=["MALFORMED_MISSING","BAD_CROSS_INCIDENT_REF","TIME_SEMANTICS","MEDIA_PATH_SIZE","RETRY_INJECTION_UNSUPPORTED"]
    jsonl(FIX/"invalid-inputs.jsonl",[{"case_id":f"bad-{i:06d}","category":cats[(i-1)//8],"input":{"case":"intentionally_invalid_synthetic_fixture","index":i},"expected":"reject_or_report_unsupported_without_mutation","is_runtime_result":False} for i in range(1,41)])
    # Private expected identity membership is isolated from all importable
    # records. Identity oracle groups are labels, not application input.
    jsonl(FIX/"oracle/identities.jsonl",[{"identity_id":g["identity_id"],"person_ids":g["person_ids"],"hero":g["hero"],"canonical_age":g["canonical_age"]} for g in groups])
    # Geography contract intentionally blocks the unverified 830 locations;
    # this status is machine-readable and visible in validation output.
    blockers=[{"requirement":"1000 locations: 840 initial points and 40 areas","status":"blocked","reason":"Only four current mapped settlement anchors were verified; no approved sampling zones, historical flood boundary, Lamosanghu anchor, or area geometry is available. No coordinates were fabricated."}]
    dump(DATA/"generation-status.json",{"dataset_id":DATASET,"status":"partial_blocked","generated_at":NOW_ISO,"blockers":blockers,"generated_media_is_placeholder":True,"runtime_outputs_prefilled":False})
    print(json.dumps({k:len(v) for k,v in all_records.items()},indent=2))

if __name__=="__main__": main()
