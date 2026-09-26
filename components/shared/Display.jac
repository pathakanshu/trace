"""Shared browser-only presentation helpers. Coordinate changes with Anshu.

Explicit cl prevents pure formatting helpers from becoming server calls when
imported across feature folders in Jac 0.34. pub exports them to those modules.
"""
import from "@hugeicons/react" { HugeiconsIcon }
cl import from ..ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }

# Short label for a status badge.
cl def:pub status_label(claim_type: str) -> str {
    if claim_type == "MISSING" { return "Missing"; }
    if claim_type == "FOUND_SAFE" { return "Safe"; }
    if claim_type == "INJURED" { return "Injured"; }
    if claim_type == "DECEASED" { return "Deceased"; }
    if claim_type == "SEEN_AT_LOCATION" { return "Seen"; }
    return "No status yet";
}

# Sentence form: "Reported missing", "Reported safe", ...
cl def:pub status_sentence(claim_type: str) -> str {
    if claim_type == "MISSING" { return "Reported missing"; }
    if claim_type == "FOUND_SAFE" { return "Reported safe"; }
    if claim_type == "INJURED" { return "Reported injured"; }
    if claim_type == "DECEASED" { return "Reported deceased"; }
    if claim_type == "SEEN_AT_LOCATION" { return "Reported seen"; }
    return "Report";
}

# "POLICE" -> "Police", "COMMUNITY" -> "Community member" ...
cl def:pub source_kind(source_type: str) -> str {
    kinds = {"POLICE": "Police", "HOSPITAL": "Hospital", "COMMUNITY": "Community member", "NGO": "Aid group", "GOVERNMENT": "Government"};
    return kinds.get(source_type, "Source");
}

cl def:pub status_text(claim_type: str) -> str {
    if claim_type == "MISSING" { return "text-status-missing"; }
    if claim_type == "FOUND_SAFE" { return "text-status-safe"; }
    if claim_type == "INJURED" { return "text-status-warning"; }
    return "text-status-neutral";
}

cl def:pub status_badge(claim_type: str) -> str {
    if claim_type == "MISSING" { return "bg-status-missing-soft text-status-missing border-status-missing/40"; }
    if claim_type == "FOUND_SAFE" { return "bg-status-safe-soft text-status-safe border-status-safe/40"; }
    if claim_type == "INJURED" { return "bg-status-warning-soft text-status-warning border-status-warning/40"; }
    return "bg-status-neutral-soft text-status-neutral border-border";
}

cl def:pub status_dot(claim_type: str) -> str {
    if claim_type == "MISSING" { return "bg-status-missing"; }
    if claim_type == "FOUND_SAFE" { return "bg-status-safe"; }
    if claim_type == "INJURED" { return "bg-status-warning"; }
    return "bg-status-neutral";
}

# "2026-09-21T09:15:00" -> "Sep 21, 9:15 AM"
cl def:pub friendly_time(iso: str) -> str {
    if not iso { return "Time unknown"; }
    if len(iso) < 16 { return iso; }
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    hour = int(iso[11:13]);
    suffix = "AM" if hour < 12 else "PM";
    hour12 = hour % 12;
    if hour12 == 0 { hour12 = 12; }
    zone = " UTC" if iso.endswith("+00:00") or iso.endswith("Z") else "";
    return months[int(iso[5:7]) - 1] + " " + str(int(iso[8:10])) + ", " + str(hour12) + ":" + iso[14:16] + " " + suffix + zone;
}

cl def:pub plural(n: int, word: str) -> str {
    return str(n) + " " + word + ("" if n == 1 else "s");
}

cl def:pub SectionHeading(title: str, subtitle: str = "") -> JsxElement {
    return <div className="flex flex-col gap-1">
        <h2 className="font-display text-2xl leading-tight tracking-tight">{title}</h2>
        {subtitle and <p className="text-sm text-muted-foreground">{subtitle}</p>}
    </div>;
}

cl def:pub EmptyPanel(icon: any, title: str, text: str) -> JsxElement {
    return <Empty className="border border-dashed border-border pt-8 pb-8">
        <EmptyHeader>
            <EmptyMedia variant="icon"><HugeiconsIcon icon={icon} strokeWidth={2} /></EmptyMedia>
            <EmptyTitle>{title}</EmptyTitle>
            <EmptyDescription>{text}</EmptyDescription>
        </EmptyHeader>
    </Empty>;
}
