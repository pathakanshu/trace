"""Browser-only helpers for the Graph inspector. Pure formatting, no server calls.

Explicit cl keeps them in the client bundle (see components/shared/Display.jac).
"""

# Order and plain-language titles for the record groups.
glob GRAPH_KIND_ORDER: list[str] = [
    "Incident", "Person", "Claim", "Source", "Organization", "Alert",
    "Subscription", "Media", "Signal", "Location", "Activity"
];

cl def:pub kind_title(kind: str) -> str {
    titles = {
        "Incident": "Incident", "Person": "People", "Claim": "Claims",
        "Source": "Sources", "Organization": "Organizations", "Alert": "Alerts",
        "Subscription": "Subscriptions", "Media": "Media", "Signal": "Verification signals",
        "Location": "Locations", "Activity": "Walker activity (ran)"
    };
    return titles.get(kind, kind);
}

cl def:pub kind_order() -> list[str] {
    return GRAPH_KIND_ORDER;
}

# Human wording for an edge, read in its stored direction.
cl def:pub edge_phrase(kind: str) -> str {
    phrases = {
        "Involves": "involves", "Contains": "contains", "Asserts": "asserts",
        "About": "is about", "SupportedBy": "is supported by", "Depicts": "depicts",
        "LocatedAt": "is located at", "HasSignal": "has signal",
        "HasSubscription": "has subscription", "Receives": "receives",
        "Triggered": "triggered", "PublishesAs": "publishes as",
        "IdentityDecision": "identity decision with", "ExactCopyOf": "is an exact copy of",
        "DuplicateCandidate": "may be the same person as", "Touched": "touched"
    };
    return phrases.get(kind, kind);
}

# Badge colour per provenance status. Token classes only.
cl def:pub badge_tone(badge: str) -> str {
    if badge == "stored" { return "border-border bg-muted text-foreground"; }
    if badge == "confirmed" { return "border-status-safe/40 bg-status-safe-soft text-status-safe"; }
    if badge == "rejected" { return "border-status-missing/40 bg-status-missing-soft text-status-missing"; }
    if badge == "candidate" { return "border-dashed border-status-warning/60 bg-status-warning-soft text-status-warning"; }
    if badge == "derived" { return "border-dashed border-primary/50 bg-primary/10 text-primary"; }
    if badge == "simulated" { return "border-status-warning/40 bg-status-warning-soft text-status-warning"; }
    if badge == "walker ran" { return "border-primary/40 bg-primary/10 text-primary"; }
    return "border-border bg-muted/60 text-muted-foreground";
}

cl def:pub badge_hint(badge: str) -> str {
    hints = {
        "stored": "Persisted in the graph",
        "confirmed": "A person confirmed this link",
        "rejected": "A person rejected this link",
        "candidate": "Computed on read by ResolveWalker's rule; not stored, not confirmed",
        "derived": "Computed on read; not a stored edge",
        "simulated": "Demo stand-in, not a real check",
        "walker ran": "Recorded when a walker actually ran",
        "seed": "Created by the demo seed",
        "unscoped": "Logged before activity was tied to an incident"
    };
    return hints.get(badge, "");
}

cl def:pub short_id(jid_value: str) -> str {
    if len(jid_value) <= 12 { return jid_value; }
    return jid_value[:6] + "..." + jid_value[len(jid_value) - 4:];
}
