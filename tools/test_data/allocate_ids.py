#!/usr/bin/env python3
"""Reserve deterministic IDs and hidden identity relationships for v1."""
from __future__ import annotations
import json, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = "bhotekoshi-2016-exercise-v1"
QUOTAS = json.loads((ROOT / "demo/spec/quotas.json").read_text())
OUT = ROOT / "tests/fixtures" / DATASET
SEED = 20160705
PREFIX = {"incident":"inc","person":"per","organization":"org","source":"src","claim":"clm","media":"med","location":"loc","facility":"fac","infrastructure":"inf","hazard":"haz","aid":"aid","contributor":"act","contribution":"con","vote":"vot","task":"tsk","subscription":"sub","investigation":"inv"}

def recid(kind, n): return f"{PREFIX[kind]}-{n:06d}"
def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(row, ensure_ascii=False, separators=(",", ":"))+"\n" for row in rows), encoding="utf-8")

def main():
    rng = random.Random(SEED)
    ages = [None] * 1000
    ages[0] = 24  # Preserve the existing fictional Maya character.
    # Twenty hero hard-negative pairs deliberately share both name and age.
    for i in range(20):
        age = rng.randint(18, 59)
        ages[i + 1] = age
        ages[i + 21] = age
    remaining_ages = ([rng.randint(0, 17) for _ in range(160)] +
                      [rng.randint(18, 59) for _ in range(569)] +
                      [rng.randint(60, 90) for _ in range(180)] + [None] * 50)
    rng.shuffle(remaining_ages)
    for i in range(41, 1000):
        ages[i] = remaining_ages.pop()
    multiplicities = [1]*40 + [2]*8 + [3]*2 + [1]*825 + [2]*112 + [3]*13
    groups=[]; person_no=0
    for gid, multiplicity in enumerate(multiplicities,1):
        people=[]
        for _ in range(multiplicity):
            person_no += 1
            people.append({"person_id":recid("person",person_no),"initial_claim_id":recid("claim",person_no)})
        groups.append({"identity_id":f"gid-{gid:06d}","person_ids":[p["person_id"] for p in people],
                       "primary_person_id":people[0]["person_id"],"canonical_age":ages[gid-1],
                       "hero":gid<=50,"initial_claim_ids":[p["initial_claim_id"] for p in people]})
    positive=[]
    for group in groups:
        ps=group["person_ids"]; cs=group["initial_claim_ids"]
        for a in range(len(ps)):
            for b in range(a+1,len(ps)):
                positive.append({"person_a_id":ps[a],"person_b_id":ps[b],"same_individual":True,
                    "evidence_claim_ids":[cs[a],cs[b]],"tags":["hidden_positive"]})
    negative=[]
    for i in range(85):
        a=groups[i+1]; b=groups[i+21]
        tag="same_name_same_age" if i<20 else ["age_disagreement","clothing_detail","time_location_context"][i%3]
        negative.append({"person_a_id":a["person_ids"][0],"person_b_id":b["person_ids"][0],"same_individual":False,
            "evidence_claim_ids":[a["initial_claim_ids"][0],b["initial_claim_ids"][0]],
            "tags":["hard_negative",tag],"rationale":"Distinct fictional people; compare separately attributed report context. Name alone is insufficient."})
    pairs=[]
    for pair in positive+negative:
        pair={"id":f"pair-{len(pairs)+1:06d}",**pair}
        pair.setdefault("rationale","Two public records belong to one hidden fictional identity; this label is evaluator-only and not resolver input.")
        pairs.append(pair)
    assert len(groups)==1000 and person_no==1150 and len(positive)==165 and len(pairs)==250
    counts=QUOTAS["primary_catalog_counts"]
    reservations={kind:[recid(kind,n) for n in range(1,count+1)] for kind,count in counts.items()}
    # Assign every claim a stable Source relationship now. T+6 is 300 primary
    # person reports in 150 two-claim reports; T+12 adds the other 850 initial
    # Person reports singly. Remaining slots preserve the final histogram.
    claim_source={}; source_claims={}
    t6_claims=[group["initial_claim_ids"][0] for group in groups[:300]]
    source_no=1
    for i in range(0,len(t6_claims),2):
        batch=t6_claims[i:i+2]; source_id=recid("source",source_no); source_no+=1
        source_claims[source_id]=batch
        for claim_id in batch: claim_source[claim_id]=source_id
    t6_set=set(t6_claims)
    other_initial=[recid("claim",n) for n in range(1,1151) if recid("claim",n) not in t6_set]
    for claim_id in other_initial:
        source_id=recid("source",source_no); source_no+=1
        source_claims[source_id]=[claim_id]; claim_source[claim_id]=source_id
    later_claims=[recid("claim",n) for n in range(1151,3601)]
    offset=0
    for size,count in [(1,50),(2,350),(4,300),(5,100)]:
        for _ in range(count):
            batch=later_claims[offset:offset+size]; offset+=size
            source_id=recid("source",source_no); source_no+=1
            source_claims[source_id]=batch
            for claim_id in batch: claim_source[claim_id]=source_id
    assert source_no==1801 and len(claim_source)==3600
    # Five older originals are deliberately ingested after their later copies.
    # Swap source assignment with later infrastructure claims while preserving
    # every Source cardinality and the global claim/source ID reservations.
    late_arrivals=["clm-001151","clm-001152","clm-001191","clm-001192","clm-001211"]
    late_slots=[recid("claim",n) for n in range(3591,3596)]
    for old_claim,late_claim in zip(late_arrivals,late_slots):
        source_old,source_late=claim_source[old_claim],claim_source[late_claim]
        source_claims[source_old].remove(old_claim); source_claims[source_old].append(late_claim)
        source_claims[source_late].remove(late_claim); source_claims[source_late].append(old_claim)
        claim_source[old_claim],claim_source[late_claim]=source_late,source_old
    for source_id in list(source_claims):
        source_no_int=int(source_id.split("-")[1])
        if source_no_int<=1400:
            source_claims[source_id]= {"claim_ids":source_claims[source_id],"publisher":{"kind":"organization","id":recid("organization",1+(source_no_int-1)%32)}}
        else:
            source_claims[source_id]= {"claim_ids":source_claims[source_id],"publisher":{"kind":"contributor","id":recid("contributor",1+(source_no_int-1401)%80)}}
    hero_people=[pid for group in groups[:50] for pid in group["person_ids"]]
    # Four transformed families plus sixteen singleton uploads make a 24-upload
    # hero media selection with all five family classes represented.
    # All five classes: original, exact copy, resize, re-encode, crop, singleton.
    hero_media=[recid("media",n) for n in [1,121,41,161,61,181,71,191,*range(81,97)]]
    scenarios=[
      ("Maya's update",["per-000001","per-000041","med-000001"],"human identity review; later hospital report; actual alert only after app execution"),
      ("Same name, different people",["per-000002","per-000022"],"similar name and age do not confirm identity"),
      ("A family with three records",["per-000057","per-000058","per-000059"],"two reviewed associations do not grant an unreviewed third record authority"),
      ("A viral bridge photo",["med-000001","med-000121"],"exact byte copies share a hash while publication history remains visible"),
      ("Wrong location caption",["med-000003","loc-000001"],"metadata, caption and proposal remain separate unverified evidence"),
      ("Earlier copy arrives late",["med-000001","med-000121"],"later ingestion may change earliest-known publication without rewriting capture time"),
      ("Shelter capacity changes",["fac-000001","loc-000001"],"compare sourced capacity and occupancy with units and times"),
      ("Access and aid",["inf-000001","aid-000001","fac-000001"],"link reported blocked access and aid claims without balancing inventory"),
      ("Anonymous correction",["per-000001","con-000031"],"hide public display identity while retaining private contributor provenance"),
      ("Translation and source dependency",["src-000001","con-000061"],"retain original language; relays are not independent corroboration"),
      ("Historical versus current disagreement",["per-000001","clm-001151"],"late old missing report does not reverse a later reported status; equal or unknown times remain unresolved"),
      ("Failure and recovery",["med-000001","sub-000001"],"optional tool failure is recorded as unavailable; retries must be tested for idempotency")]
    plan={"dataset_id":DATASET,"seed":SEED,"status":"allocation_only; generated records and geography readiness remain separate gates",
          "primary_id_reservations":reservations,"hero_person_ids":hero_people,"hero_media_ids":hero_media,
          "late_ingest_media_claim_ids":late_arrivals,
          "identity_groups":groups,"source_claim_allocations":source_claims,"claim_to_source":claim_source,
          "story_plans":[{"id":f"scn-{i:06d}","title":title,"focal_ids":refs,"purpose":purpose} for i,(title,refs,purpose) in enumerate(scenarios,1)],
          "record_dependencies":{"all_person_records_have_initial_missing_claim":True,"hero_profile_is_subset":True,
            "private_identity_labels_are_not_application_inputs":True,"runtime_results_are_not_allocated":True}}
    (OUT/"allocation-plan.json").parent.mkdir(parents=True,exist_ok=True)
    (OUT/"allocation-plan.json").write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    write_jsonl(OUT/"oracle/identity-pairs.jsonl",pairs)
    print(json.dumps({"person_records_reserved":person_no,"identity_groups":len(groups),"hero_person_records":len(hero_people),
        "positive_pairs":len(positive),"hard_negatives":len(negative),"hero_media_uploads_reserved":len(hero_media),
        "stories_reserved":len(scenarios),"source_claim_subjects_reserved":sum(counts[k] for k in counts if k not in ["incident","person","organization","source","claim","media","location","contributor","contribution","vote","task","subscription","investigation"])} ,indent=2))

if __name__=="__main__": main()
