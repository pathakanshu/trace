"""Browser-only helpers for large incidents (the generated exercise corpus).

The corpus snapshot carries dict counts (totals, status_counts, counts_by_kind).
These helpers read them defensively so a snapshot without the fields renders
exactly like the small demo incident.
"""
cl def:pub count_of(counts: any, key: str) -> int {
    if not counts { return 0; }
    if key in counts { return counts[key]; }
    return 0;
}

# 8027 -> "8,027". Written out so the client needs no locale support.
cl def:pub fmt_count(n: int) -> str {
    digits = str(n);
    out = "";
    while len(digits) > 3 {
        out = "," + digits[len(digits) - 3:] + out;
        digits = digits[:len(digits) - 3];
    }
    return digits + out;
}

# Same wording as Display.status_label (inlined: this file has only browser
# functions, so a module-level import would not reach the client bundle).
cl def:pub status_key_label(key: str) -> str {
    if key == "MISSING" { return "Missing"; }
    if key == "FOUND_SAFE" { return "Safe"; }
    if key == "INJURED" { return "Injured"; }
    if key == "DECEASED" { return "Deceased"; }
    if key == "SEEN_AT_LOCATION" { return "Seen"; }
    if key == "" or key == "NONE" or key == "UNKNOWN" { return "Unknown"; }
    words = key.replace("_", " ").lower();
    return words[0].upper() + words[1:];
}

# Organization types in the corpus go beyond the demo's five source kinds.
cl def:pub org_type_label(kind: str) -> str {
    known = {"POLICE": "Police", "HOSPITAL": "Hospital", "NGO": "Aid group",
        "GOVERNMENT": "Government", "POLICE_RESCUE": "Police and rescue",
        "COMMUNITY_NEWS": "Community news", "COMMUNITY": "Community member"};
    if kind in known { return known[kind]; }
    return status_key_label(kind) if kind else "Organization";
}

cl def:pub is_corpus_snapshot(snapshot: any) -> bool {
    return bool(snapshot) and bool(snapshot.is_corpus);
}

# Compact totals strip shown under the incident title for the corpus only.
cl def:pub CorpusTotals(snapshot: any) -> JsxElement {
    totals: any = snapshot.totals;
    items = [
        ["People", "people"], ["Claims", "claims"], ["Source reports", "sources"],
        ["Organizations", "organizations"], ["Media", "media"], ["Locations", "locations"]
    ];
    missing: any = snapshot.not_imported;
    skipped: list[str] = [];
    if missing {
        for key in missing.keys() {
            if missing[key] > 0 { skipped.append(str(missing[key]) + " " + key.replace("_", " ")); }
        }
    }
    return <section aria-label="Corpus totals" className="flex flex-col gap-2">
        <dl className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {for item in items {
                <div key={item[1]} className="min-w-0 rounded-md border border-border bg-card px-2.5 py-2">
                    <dt className="truncate text-[11px] text-muted-foreground">{item[0]}</dt>
                    <dd className="font-display text-lg leading-tight tabular-nums">{fmt_count(count_of(totals, item[1]))}</dd>
                </div>
            }}
        </dl>
        <p className="text-xs text-muted-foreground">
            <span className="font-medium text-status-warning">{"Generated exercise data, partially complete."}</span>
            {(" Not imported: " + ", ".join(skipped) + ".") if skipped else ""}
        </p>
    </section>;
}
