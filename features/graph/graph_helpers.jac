"""Browser-only helpers for the Graph inspector. Pure formatting, no server calls.

Explicit cl keeps them in the client bundle (see components/shared/Display.jac).
"""

# Plain-language titles for the record groups.

cl def:pub kind_title(kind: str) -> str {
    titles = {
        "Incident": "Incident", "Person": "People",
        "IdentityDecision": "Identity reviews", "Claim": "Claims",
        "Source": "Sources", "Organization": "Organizations", "Alert": "Alerts",
        "Subscription": "Subscriptions", "Media": "Media", "Signal": "Verification signals",
        "Location": "Locations", "Activity": "Walker activity (ran)",
        "Investigation": "Report investigations"
    };
    return titles.get(kind, kind);
}

# Group order. Kept inside the function: a server glob is not shipped to the client.
cl def:pub kind_order() -> list[str] {
    return [
        "Incident", "Person", "IdentityDecision", "Claim", "Source", "Organization", "Alert",
        "Subscription", "Media", "Signal", "Location", "Investigation", "Activity"
    ];
}

# Human wording for an edge, read in its stored direction.
cl def:pub edge_phrase(kind: str) -> str {
    phrases = {
        "Involves": "involves", "Contains": "contains", "Asserts": "asserts",
        "About": "is about", "SupportedBy": "is supported by", "Depicts": "depicts",
        "LocatedAt": "is located at", "HasSignal": "has signal",
        "HasSubscription": "has subscription", "Receives": "receives",
        "Triggered": "triggered", "ClaimRef": "is named as the cause of",
        "HasOrganization": "has publisher", "Publishes": "publishes",
        "Reviews": "reviews", "ExactCopyOf": "is an exact copy of",
        "DuplicateCandidate": "may be the same person as", "Touched": "touched",
        "HasInvestigation": "has investigation", "InvestigationCitation": "cites"
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

# Diagram node colour per record kind. SVG fill token classes only.
cl def:pub kind_fill(kind: str) -> str {
    fills = {
        "Incident": "fill-foreground", "Person": "fill-primary",
        "IdentityDecision": "fill-status-safe", "Claim": "fill-status-warning",
        "Source": "fill-status-neutral", "Organization": "fill-status-neutral",
        "Alert": "fill-status-missing", "Subscription": "fill-chart-1",
        "Media": "fill-chart-3", "Signal": "fill-chart-4", "Location": "fill-chart-2",
        "Investigation": "fill-chart-5", "Activity": "fill-muted-foreground"
    };
    return fills.get(kind, "fill-muted-foreground");
}

# Diagram edge colour per provenance status, matching badge_tone's meanings.
cl def:pub edge_stroke(status: str) -> str {
    if status == "confirmed" { return "stroke-status-safe"; }
    if status == "rejected" { return "stroke-status-missing"; }
    if status == "candidate" { return "stroke-status-warning"; }
    if status == "derived" { return "stroke-primary"; }
    return "stroke-muted-foreground";
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
        "demo": "Fictional demo publisher, not an authenticated organization"
    };
    return hints.get(badge, "");
}

cl def:pub short_id(jid_value: str) -> str {
    if len(jid_value) <= 12 { return jid_value; }
    return jid_value[:6] + "..." + jid_value[len(jid_value) - 4:];
}
