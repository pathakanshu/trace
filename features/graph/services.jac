"""Graph inspector projection (Miguel).

Reads the SAME stored graph every tab uses and flattens one incident into
typed node and edge views. It writes nothing and keeps no copy.

    build_graph_snapshot(incident) -> GraphSnapshot

Every node view carries its real jid. Every edge view names the typed Jac
edge it came from (Asserts, About, Triggered, ...). Relationships that are
NOT stored (ResolveWalker duplicate candidates, ActivityEntry.target_ids
references, Alert.claim_id when no Triggered edge exists) are marked
derived=True with status "candidate"/"derived".

Anshu wires this into DashboardSnapshot as f"graph: GraphSnapshot":
    snap.graph = build_graph_snapshot(incident, snap.duplicates);
"""

import json;
import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location, VerificationSignal,
    Subscription, Alert, ActivityEntry, Organization, IdentityDecision,
    InvestigationRun
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, Depicts, LocatedAt,
    HasSignal, HasSubscription, Receives, Triggered, HasOrganization,
    Publishes, Reviews, ExactCopyOf, HasInvestigation
}
import from walkers.resolve { DuplicateCandidate }

# ---------- View objects (sent to the browser) ----------

obj GraphField {
    has name: str, value: str;
}

obj GraphNodeView {
    has id: str,
        kind: str,
        label: str,
        fields: list[GraphField] = [],
        provenance: list[GraphField] = [],
        badges: list[str] = [];
}

obj GraphEdgeView {
    has id: str,
        kind: str,
        from_id: str,
        to_id: str,
        # "stored" | "confirmed" | "rejected" | "candidate" | "derived"
        status: str = "stored",
        derived: bool = False,
        fields: list[GraphField] = [];
}

obj GraphSnapshot {
    has incident_id: str = "",
        incident_name: str = "",
        nodes: list[GraphNodeView] = [],
        edges: list[GraphEdgeView] = [],
        # Every node in the incident, even when `nodes` is capped (corpus).
        total_nodes: int = 0,
        counts_by_kind: dict[str, int] = {};
}

# ---------- Builder ----------

# Collects nodes (deduplicated by jid) and edges while walking out from one incident.
obj _Collector {
    has nodes: dict[str, GraphNodeView] = {},
        order: list[str] = [],
        edges: list[GraphEdgeView] = [],
        edge_keys: list[str] = [],
        # alert jid -> Alert.claim_id, for alerts without a Triggered edge.
        claim_refs: dict[str, str] = {};

    def add_node(view: GraphNodeView) -> bool {
        if view.id in self.nodes {
            return False;
        }
        self.nodes[view.id] = view;
        self.order.append(view.id);
        return True;
    }

    def add_edge(
        kind: str, from_id: str, to_id: str, status: str = "stored",
        fields: list[GraphField] = []
    ) -> None {
        key = f"{kind}:{from_id}:{to_id}";
        if key in self.edge_keys {
            return;
        }
        self.edge_keys.append(key);
        self.edges.append(GraphEdgeView(
            id=key, kind=kind, from_id=from_id, to_id=to_id, status=status,
            derived=status in ["candidate", "derived"], fields=fields
        ));
    }
}

def _f(name: str, value: any) -> GraphField {
    return GraphField(name=name, value=str(value) if value != "" else "not recorded");
}

# duplicates: the People tab's ResolveWalker results (DashboardSnapshot.duplicates),
# reused as-is so the Graph tab shows exactly the same candidates.
# max_nodes > 0 caps the projection (the corpus would be thousands of nodes);
# full_counts then supplies the real per-kind counts measured by the caller.
def build_graph_snapshot(
    incident: Incident | None, duplicates: list[DuplicateCandidate] = [],
    max_nodes: int = 0, full_counts: dict[str, int] = {}
) -> GraphSnapshot {
    if incident is None {
        return GraphSnapshot();
    }
    col = _Collector();
    inc_id = jid(incident);
    col.add_node(GraphNodeView(
        id=inc_id, kind="Incident", label=incident.name,
        fields=[
            _f("name", incident.name), _f("description", incident.description),
            _f("region", incident.region), _f("start_time", incident.start_time)
        ],
        badges=["stored"]
    ));

    people = [incident ->:Involves:->];
    for person in people {
        if max_nodes and len(col.order) >= max_nodes { break; }
        pid = jid(person);
        col.add_node(_person_view(person));
        col.add_edge("Involves", inc_id, pid);

        for claim in [person <-:About:<-] {
            _add_claim(col, claim);
            col.add_edge("About", jid(claim), pid);
        }
        for sub in [person ->:HasSubscription:->] {
            sid = jid(sub);
            col.add_node(GraphNodeView(
                id=sid, kind="Subscription", label=sub.subscriber_name,
                fields=[
                    _f("subscriber_name", sub.subscriber_name),
                    _f("subscriber_contact", sub.subscriber_contact)
                ],
                badges=["stored"]
            ));
            col.add_edge("HasSubscription", pid, sid);
            for alert in [sub ->:Receives:->] {
                _add_alert(col, alert, sub.subscriber_name);
                col.add_edge("Receives", sid, jid(alert));
            }
        }
        # Human identity reviews (stored). Candidates are added below as derived.
        for decision in [person <-:Reviews:<-] {
            _add_identity_decision(col, decision);
            col.add_edge("Reviews", jid(decision), pid, _decision_status(decision));
        }
    }

    for org in [incident ->:HasOrganization:->] {
        if max_nodes and len(col.order) >= max_nodes { break; }
        _add_organization(col, org);
        col.add_edge("HasOrganization", inc_id, jid(org));
    }

    for m in [incident ->:Contains:->] {
        if max_nodes and len(col.order) >= max_nodes { break; }
        _add_media(col, m);
        col.add_edge("Contains", inc_id, jid(m));
    }

    for run in [incident ->:HasInvestigation:->] {
        _add_investigation(col, run, inc_id);
    }

    # Derived: ResolveWalker's candidates from the same dashboard read. Not stored.
    for cand in duplicates {
        if cand.person_a_id in col.nodes and cand.person_b_id in col.nodes {
            col.add_edge(
                "DuplicateCandidate", cand.person_a_id, cand.person_b_id, "candidate",
                [
                    _f("computed_by", "ResolveWalker (same results as the People tab)"),
                    _f("confidence", cand.confidence),
                    _f("reasons", ", ".join(cand.reasons))
                ]
            );
        }
    }

    _add_alert_claim_refs(col);
    _add_activity(col, inc_id);

    snap = GraphSnapshot(incident_id=inc_id, incident_name=incident.name);
    snap.nodes = [col.nodes[k] for k in col.order];
    snap.edges = col.edges;
    if full_counts {
        snap.counts_by_kind = dict(full_counts);
    } else {
        for view in snap.nodes {
            snap.counts_by_kind[view.kind] = snap.counts_by_kind.get(view.kind, 0) + 1;
        }
    }
    snap.total_nodes = sum(snap.counts_by_kind.values());
    return snap;
}

# ---------- Per-kind projections ----------

def _person_view(person: Person) -> GraphNodeView {
    return GraphNodeView(
        id=jid(person), kind="Person", label=person.name,
        fields=[_f("name", person.name), _f("age", person.age if person.age > 0 else ""), _f("notes", person.notes)],
        provenance=[_f("status", "Not stored on Person. See the Claims about this record.")],
        badges=["stored"]
    );
}

def _add_claim(col: _Collector, claim: Claim) -> None {
    cid = jid(claim);
    sources = [claim <-:Asserts:<-];
    source_name = sources[0].name if sources else "";
    if not col.add_node(GraphNodeView(
        id=cid, kind="Claim", label=f"{claim.claim_type} ({source_name or 'unknown source'})",
        fields=[
            _f("claim_type", claim.claim_type), _f("value", claim.value),
            _f("reported_at (by the source)", claim.timestamp or "unknown"),
            _f("ingested_at (stored by Trace)", claim.ingested_at),
            _f("notes", claim.notes), _f("seen_by_watch", claim.seen_by_watch)
        ],
        provenance=[
            _f("source", source_name), _f("source_reference", claim.source_reference),
            _f("extraction_method", claim.extraction_method),
            _f("original_content", claim.original_content),
            _f("payload_hash", claim.payload_hash), _f("incident_id", claim.incident_id)
        ],
        badges=["stored"]
    )) {
        return;
    }
    for src in sources {
        srcid = jid(src);
        orgs = [src <-:Publishes:<-];
        col.add_node(GraphNodeView(
            id=srcid, kind="Source", label=src.name,
            fields=[_f("name", src.name), _f("source_type", src.source_type), _f("url", src.url)],
            provenance=[_f("organization", orgs[0].name if orgs else "")],
            badges=["stored"]
        ));
        col.add_edge("Asserts", srcid, cid);
        for org in orgs {
            _add_organization(col, org);
            col.add_edge("Publishes", jid(org), srcid);
        }
    }
    for m in [claim ->:SupportedBy:->] {
        _add_media(col, m);
        col.add_edge("SupportedBy", cid, jid(m));
    }
    for alert in [claim ->:Triggered:->] {
        for e in [edge claim ->:Triggered:-> alert] {
            col.add_edge("Triggered", cid, jid(alert), "stored", [
                _f("walker_name", e.walker_name), _f("created_at", e.created_at)
            ]);
        }
    }
}

def _add_organization(col: _Collector, org: Organization) -> None {
    badges = ["stored"];
    if org.is_demo {
        badges.append("demo");
    }
    col.add_node(GraphNodeView(
        id=jid(org), kind="Organization", label=org.name,
        fields=[_f("name", org.name), _f("organization_type", org.organization_type)],
        provenance=[_f("is_demo", "yes (fictional publisher, not an authenticated identity)" if org.is_demo else "no")],
        badges=badges
    ));
}

def _decision_status(decision: IdentityDecision) -> str {
    if decision.decision == "CONFIRMED" { return "confirmed"; }
    if decision.decision == "REJECTED" { return "rejected"; }
    return "stored";
}

def _add_identity_decision(col: _Collector, decision: IdentityDecision) -> None {
    status = _decision_status(decision);
    col.add_node(GraphNodeView(
        id=jid(decision), kind="IdentityDecision",
        label=f"{decision.decision}: {decision.person_a_name} / {decision.person_b_name}",
        fields=[
            _f("decision", decision.decision), _f("person_a", decision.person_a_name),
            _f("person_b", decision.person_b_name), _f("note", decision.note),
            _f("basis", ", ".join(decision.basis)), _f("history", "; ".join(decision.history))
        ],
        provenance=[_f("reviewer", decision.reviewer), _f("decided_at", decision.decided_at)],
        badges=["stored", status] if status != "stored" else ["stored"]
    ));
}

def _add_alert(col: _Collector, alert: Alert, subscriber: str) -> None {
    causes = [alert <-:Triggered:<-];
    cause = jid(causes[0]) if causes else alert.claim_id;
    col.add_node(GraphNodeView(
        id=jid(alert), kind="Alert", label=f"Alert to {subscriber}",
        fields=[_f("message", alert.message), _f("severity", alert.severity), _f("created_at", alert.created_at)],
        provenance=[
            _f("created_by", "WatchWalker"),
            _f("caused_by_claim", cause or "not recorded"),
            _f("link", "stored Triggered edge" if causes else "Alert.claim_id field (no Triggered edge)" if cause else "not recorded")
        ],
        badges=["stored"]
    ));
    if not causes and alert.claim_id {
        col.claim_refs[jid(alert)] = alert.claim_id;
    }
}

# A run's citations are graph ids read back out of its saved result_json, not a
# stored edge to each claim, so those links are drawn derived.
def _add_investigation(col: _Collector, run: InvestigationRun, inc_id: str) -> None {
    rid = jid(run);
    try {
        result = json.loads(run.result_json);
    } except Exception {
        result = {};
    }
    status = result.get("status", "");
    mode = run.mode or result.get("mode", "");
    col.add_node(GraphNodeView(
        id=rid, kind="Investigation", label=f"{status or 'UNKNOWN'} · {mode or 'UNKNOWN'}",
        fields=[
            _f("status", status), _f("mode", mode), _f("model", result.get("model", "")),
            _f("run_at", result.get("run_at", run.created_at)),
            _f("prompt_version", result.get("prompt_version", ""))
        ],
        provenance=[_f("created_at", run.created_at), _f("fingerprint", run.fingerprint)],
        badges=["stored"]
    ));
    col.add_edge("HasInvestigation", inc_id, rid);
    for citation in result.get("citations", []) {
        claim_id = citation.get("claim_id", "");
        if claim_id and claim_id in col.nodes {
            col.add_edge("InvestigationCitation", rid, claim_id, "derived", [
                _f("source_name", citation.get("source_name", "")),
                _f("from", "InvestigationRun.result_json citations (not a stored edge)")
            ]);
        }
    }
}

# Alerts with a claim_id but no Triggered edge still name their claim. Draw that
# as a derived link so the UI never presents it as a stored edge.
def _add_alert_claim_refs(col: _Collector) -> None {
    for (aid, claim_id) in col.claim_refs.items() {
        if claim_id in col.nodes {
            col.add_edge("ClaimRef", claim_id, aid, "derived", [
                _f("from", "Alert.claim_id (a recorded reference, not a graph edge)")
            ]);
        }
    }
}

def _add_media(col: _Collector, m: Media) -> None {
    mid = jid(m);
    badges = ["stored"];
    if m.origin == "seed" {
        badges.append("seed");
    }
    if not col.add_node(GraphNodeView(
        id=mid, kind="Media", label=m.description or m.url,
        fields=[
            _f("media_type", m.media_type), _f("url", m.url), _f("captured_at", m.captured_at),
            _f("description", m.description),
            _f("earliest_known_copy", "yes (earliest known copy, not proof of origin)" if m.earliest_known_copy else "no"),
            _f("content_hash", m.content_hash), _f("exif_gps_present", m.exif_gps_present),
            _f("community_location", m.community_location)
        ],
        provenance=[_f("origin", m.origin), _f("uploaded_by", m.uploaded_by), _f("uploaded_at", m.uploaded_at)],
        badges=badges
    )) {
        return;
    }
    for loc in [m ->:LocatedAt:->] {
        col.add_node(GraphNodeView(
            id=jid(loc), kind="Location", label=loc.name,
            fields=[_f("name", loc.name), _f("latitude", loc.latitude), _f("longitude", loc.longitude)],
            badges=["stored"]
        ));
        col.add_edge("LocatedAt", mid, jid(loc));
    }
    for p in [m ->:Depicts:->] {
        col.add_node(_person_view(p));
        col.add_edge("Depicts", mid, jid(p));
    }
    for s in [m ->:HasSignal:->] {
        sig_badges = ["stored"];
        if s.method == "simulated" {
            sig_badges.append("simulated");
        }
        col.add_node(GraphNodeView(
            id=jid(s), kind="Signal", label=f"{s.signal_type}: {s.value}",
            fields=[
                _f("signal_type", s.signal_type), _f("value", s.value),
                _f("confidence", s.confidence), _f("explanation", s.explanation)
            ],
            provenance=[_f("method", s.method)],
            badges=sig_badges
        ));
        col.add_edge("HasSignal", mid, jid(s));
    }
    for other in [m ->:ExactCopyOf:->] {
        _add_media(col, other);
        for e in [edge m ->:ExactCopyOf:-> other] {
            col.add_edge("ExactCopyOf", mid, jid(other), "stored", [
                _f("hash_algo", e.hash_algo), _f("detected_by", e.detected_by), _f("detected_at", e.detected_at)
            ]);
        }
    }
}

# Only walker steps that actually ran (ActivityEntry nodes on root), scoped the
# same way as the dashboard's activity feed: incident_id == jid(incident).
def _add_activity(col: _Collector, incident_id: str) -> None {
    for entry in [root -->[?:ActivityEntry]] {
        if entry.incident_id != incident_id {
            continue;
        }
        aid = jid(entry);
        badges = ["stored", "walker ran"];
        col.add_node(GraphNodeView(
            id=aid, kind="Activity", label=f"{entry.walker_name}: {entry.message}",
            fields=[_f("walker_name", entry.walker_name), _f("message", entry.message)],
            provenance=[
                _f("walker", entry.walker_name), _f("created_at", entry.created_at),
                _f("incident_id", entry.incident_id),
                _f("target_ids", ", ".join(entry.target_ids))
            ],
            badges=badges
        ));
        for tid in entry.target_ids {
            if tid in col.nodes {
                col.add_edge("Touched", aid, tid, "derived", [
                    _f("from", "ActivityEntry.target_ids (a recorded reference, not a graph edge)")
                ]);
            }
        }
    }
}
