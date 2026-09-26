"""Graph inspector projection (Miguel).

Reads the SAME stored graph every tab uses and flattens one incident into
typed node and edge views. It writes nothing and keeps no copy.

    build_graph_snapshot(incident) -> GraphSnapshot

Every node view carries its real jid. Every edge view names the typed Jac
edge it came from (Asserts, About, Triggered, ...). Relationships that are
NOT stored (ResolveWalker duplicate candidates, ActivityEntry.target_ids
references) are marked derived=True with status "candidate"/"derived".

Anshu wires this into DashboardSnapshot as f"graph: GraphSnapshot".
"""

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location, VerificationSignal,
    Subscription, Alert, ActivityEntry, Organization
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, Depicts, LocatedAt,
    HasSignal, HasSubscription, Receives, Triggered, PublishesAs,
    IdentityDecision, ExactCopyOf
}
import from walkers.resolve { score_pair }

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
        edges: list[GraphEdgeView] = [];
}

# ---------- Builder ----------

# Collects nodes (deduplicated by jid) and edges while walking out from one incident.
obj _Collector {
    has nodes: dict[str, GraphNodeView] = {},
        order: list[str] = [],
        edges: list[GraphEdgeView] = [],
        edge_keys: list[str] = [];

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

def build_graph_snapshot(incident: Incident | None) -> GraphSnapshot {
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
        # Human identity decisions (stored). Candidates are added below as derived.
        for other in [person ->:IdentityDecision:->] {
            for e in [edge person ->:IdentityDecision:-> other] {
                col.add_edge(
                    "IdentityDecision", pid, jid(other),
                    "confirmed" if e.decision == "CONFIRMED" else "rejected",
                    [
                        _f("decision", e.decision), _f("reviewer", e.reviewer),
                        _f("decided_at", e.decided_at), _f("rationale", e.rationale),
                        _f("candidate_confidence", e.candidate_confidence),
                        _f("candidate_reasons", ", ".join(e.candidate_reasons))
                    ]
                );
            }
        }
    }

    for m in [incident ->:Contains:->] {
        _add_media(col, m);
        col.add_edge("Contains", inc_id, jid(m));
    }

    # Derived: ResolveWalker's scoring rule, recomputed. Not stored in the graph.
    for i in range(len(people)) {
        for j in range(i + 1, len(people)) {
            cand = score_pair(people[i], people[j], incident.name);
            if cand {
                col.add_edge(
                    "DuplicateCandidate", cand.person_a_id, cand.person_b_id, "candidate",
                    [
                        _f("computed_by", "ResolveWalker.score_pair (recomputed on read)"),
                        _f("confidence", cand.confidence),
                        _f("reasons", ", ".join(cand.reasons))
                    ]
                );
            }
        }
    }

    _add_activity(col, incident.name);

    snap = GraphSnapshot(incident_id=inc_id, incident_name=incident.name);
    snap.nodes = [col.nodes[k] for k in col.order];
    snap.edges = col.edges;
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
            _f("timestamp (reported)", claim.timestamp), _f("notes", claim.notes),
            _f("seen_by_watch", claim.seen_by_watch)
        ],
        provenance=[
            _f("source", source_name), _f("ingested_by", claim.ingested_by),
            _f("ingested_at", claim.ingested_at), _f("report_ref", claim.report_ref)
        ],
        badges=["stored"]
    )) {
        return;
    }
    for src in sources {
        srcid = jid(src);
        orgs = [src <-:PublishesAs:<-];
        col.add_node(GraphNodeView(
            id=srcid, kind="Source", label=src.name,
            fields=[_f("name", src.name), _f("source_type", src.source_type), _f("url", src.url)],
            provenance=[_f("organization", orgs[0].name if orgs else "")],
            badges=["stored"]
        ));
        col.add_edge("Asserts", srcid, cid);
        for org in orgs {
            col.add_node(GraphNodeView(
                id=jid(org), kind="Organization", label=org.name,
                fields=[_f("name", org.name), _f("org_type", org.org_type)],
                badges=["stored"]
            ));
            col.add_edge("PublishesAs", jid(org), srcid);
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

def _add_alert(col: _Collector, alert: Alert, subscriber: str) -> None {
    causes = [alert <-:Triggered:<-];
    col.add_node(GraphNodeView(
        id=jid(alert), kind="Alert", label=f"Alert to {subscriber}",
        fields=[_f("message", alert.message), _f("severity", alert.severity), _f("created_at", alert.created_at)],
        provenance=[
            _f("created_by", "WatchWalker" if causes else ""),
            _f("caused_by_claim", jid(causes[0]) if causes else "not linked (created before Triggered edges existed)")
        ],
        badges=["stored"]
    ));
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

# Only walker steps that actually ran (ActivityEntry nodes on root).
# Entries without incident_name predate scoping; they are shown but badged "unscoped".
def _add_activity(col: _Collector, incident_name: str) -> None {
    for entry in [root -->[?:ActivityEntry]] {
        if entry.incident_name != "" and entry.incident_name != incident_name {
            continue;
        }
        aid = jid(entry);
        badges = ["stored", "walker ran"];
        if entry.incident_name == "" {
            badges.append("unscoped");
        }
        col.add_node(GraphNodeView(
            id=aid, kind="Activity", label=f"{entry.walker_name}: {entry.message}",
            fields=[_f("walker_name", entry.walker_name), _f("message", entry.message)],
            provenance=[
                _f("walker", entry.walker_name), _f("created_at", entry.created_at),
                _f("incident_name", entry.incident_name),
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
