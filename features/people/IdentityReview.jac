"""Human identity review for one proposed association (Gabriel).

Shows both original records side by side with only what the graph actually
holds: rule-based similarities from ResolveWalker, observable differences,
and details that are unknown. No confidence score is invented here.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    UserSearch01Icon, CheckmarkCircle02Icon, Cancel01Icon, Clock01Icon
}
import from ...components.ui.badge { Badge }
import from ...components.ui.button { Button }
import from ...components.shared.Display {
    SectionHeading, status_sentence, status_text, source_kind, friendly_time, status_label
}
import from ...lib.utils { cn }
sv import from ...services.trace { PersonView }
sv import from ...walkers.resolve { DuplicateCandidate, IdentityDecisionResult }
sv import from ...graph.nodes { IdentityReviewEntry }
sv import from .services { review_identity }

# Differences/unknowns come from the server (walkers/resolve.jac compare_*),
# which orders status reports by report timestamp and is covered by tests.

def all_claim_ids(a: PersonView, b: PersonView) -> list[str] {
    return [c.id for c in a.claims] + [c.id for c in b.claims];
}

def:pub RecordColumn(person: PersonView, label: str, cited: list[str]) -> JsxElement {
    return <div className="flex min-w-0 flex-col gap-3 rounded-md border border-border bg-card pt-4 pb-4 pl-4 pr-4">
        <div className="flex flex-col gap-0.5">
            <span className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">{label}</span>
            <span className="font-display text-lg leading-tight">{person.name}</span>
            <span className="text-xs text-muted-foreground">
                {("Age " + str(person.age)) if person.age > 0 else "Age unknown"}
                {" - record " + person.id[-8:]}
            </span>
        </div>
        {person.notes and <span className="text-xs text-muted-foreground">{person.notes}</span>}
        <div className="flex flex-col gap-2">
            {if len(person.claims) == 0 {
                <span className="text-xs italic text-muted-foreground">{"No reports on this record."}</span>
            }}
            {for c in person.claims {
                <div key={c.id} className={cn("flex flex-col gap-1 rounded-md border bg-background pt-2.5 pb-2.5 pl-3 pr-3",
                    "border-primary" if c.id in cited else "border-border")}>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                        <span className={cn("text-sm font-semibold", status_text(c.claim_type))}>{status_sentence(c.claim_type)}</span>
                        {c.id in cited and <Badge variant="outline">{"Cited by agent"}</Badge>}
                        <span className="flex items-center gap-1 text-xs text-muted-foreground">
                            <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-3.5" />{friendly_time(c.timestamp)}
                        </span>
                    </div>
                    <span className="text-sm">{c.value}</span>
                    <span className="text-xs text-muted-foreground">
                        {"Source: "}<span className="font-medium text-foreground">{c.source_name}</span>{" (" + source_kind(c.source_type) + ")"}
                    </span>
                    {c.notes and <span className="text-xs text-muted-foreground">{c.notes}</span>}
                    <span className="text-[11px] text-muted-foreground">{"Claim " + c.id[-8:]}</span>
                </div>
            }}
        </div>
    </div>;
}

def:pub FactList(title: str, items: list[str], tone: str) -> JsxElement {
    return <div className="flex flex-col gap-1.5">
        <span className={cn("text-xs font-semibold uppercase tracking-wide", tone)}>{title}</span>
        {if len(items) == 0 {
            <span className="text-sm text-muted-foreground">{"None found in the records."}</span>
        }}
        <ul className="flex flex-col gap-1 pl-4 text-sm">
            {for (i, it) in enumerate(items) {
                <li key={str(i)} className="list-disc">{it}</li>
            }}
        </ul>
    </div>;
}

def decision_badge(decision: str) -> str {
    if decision == "CONFIRMED" { return "bg-status-safe-soft text-status-safe border-status-safe/40"; }
    if decision == "REJECTED" { return "bg-status-missing-soft text-status-missing border-status-missing/40"; }
    return "bg-status-neutral-soft text-status-neutral border-border";
}

def decision_label(decision: str) -> str {
    if decision == "CONFIRMED" { return "Confirmed same person"; }
    if decision == "REJECTED" { return "Rejected: different people"; }
    return "Awaiting human review";
}

def:pub IdentityReview(
    candidate: DuplicateCandidate,
    personA: PersonView | None,
    personB: PersonView | None,
    onRefresh: Callable[[], any],
    onClose: Callable[[], None]
) -> JsxElement {
    has reviewer: str = "", note: str = "", busy: str = "", message: str = "", error: str = "";

    async def submit(decision: str) -> None {
        if not reviewer.strip() {
            error = "Enter your name so the decision is attributed.";
            return;
        }
        busy = decision;
        error = "";
        message = "";
        try {
            evidence: list[str] = all_claim_ids(personA, personB) if personA and personB else [];
            res: IdentityDecisionResult = await review_identity(
                candidate.incident_name, candidate.person_a_id, candidate.person_b_id,
                decision, reviewer, note, candidate.reasons, evidence
            );
            if res.ok {
                message = res.message;
                if res.changed { await onRefresh(); }
            } else {
                error = res.message;
            }
        } except Exception as e {
            error = "Could not save the decision: " + str(e);
        }
        busy = "";
    }

    if personA == None or personB == None {
        return <section className="rounded-md border border-border bg-card pt-4 pb-4 pl-4 pr-4 text-sm text-muted-foreground">
            {"One of these records is no longer in the graph. Refresh the dashboard."}
        </section>;
    }
    cited = candidate.cited_claim_ids;
    past: list[IdentityReviewEntry] = candidate.past_reviews;

    return <section aria-label="Identity review" className="flex flex-col gap-4 rounded-lg border border-border bg-muted/40 pt-5 pb-5 pl-4 pr-4 sm:pl-5 sm:pr-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
            <SectionHeading title="Review possible match" subtitle="Both records stay separate in the graph. Your decision is recorded with your name and the time." />
            <div className="flex items-center gap-2">
                <Badge variant="outline" className={decision_badge(candidate.decision)}>{decision_label(candidate.decision)}</Badge>
                <Button variant="ghost" size="sm" onClick={lambda { onClose(); }}>{"Close"}</Button>
            </div>
        </div>

        {candidate.decision != "PENDING" and <div className="flex flex-col gap-1 rounded-md border border-border bg-card pt-3 pb-3 pl-3 pr-3 text-sm">
            <span>
                {decision_label(candidate.decision) + " - reviewed by "}
                <span className="font-medium">{candidate.reviewer}</span>
                {" on " + friendly_time(candidate.decided_at)}
            </span>
            {candidate.note and <span className="text-xs text-muted-foreground">{"Reason: " + candidate.note}</span>}
            <span className="text-xs text-muted-foreground">{"Evidence in view: " + str(len(candidate.evidence_claim_ids)) + " report(s). Applies to records " + candidate.person_a_id[-8:] + " and " + candidate.person_b_id[-8:] + ". Neither record was merged or edited."}</span>
            {len(past) > 0 and <details className="text-xs text-muted-foreground">
                <summary className="cursor-pointer">{"Earlier reviews (" + str(len(past)) + ")"}</summary>
                <ol className="mt-2 flex flex-col gap-2 pl-4">
                    {for (i, r) in enumerate(past) {
                        <li key={str(i)} className="list-decimal">
                            {decision_label(r.decision) + " by " + r.reviewer + " on " + friendly_time(r.decided_at)}
                            {r.note and <span>{" - reason: " + r.note}</span>}
                            {len(r.basis) > 0 and <span>{" - basis: " + ", ".join(r.basis)}</span>}
                            <span>{" - evidence: " + str(len(r.evidence_claim_ids)) + " report(s)"}</span>
                        </li>
                    }}
                </ol>
            </details>}
        </div>}

        {candidate.proposed_by and <div className="flex flex-col gap-1 rounded-md border border-primary/40 bg-card pt-3 pb-3 pl-3 pr-3 text-sm">
            <span>{"Proposed by "}<span className="font-medium">{candidate.proposed_by}</span>{" - " + str(len(cited)) + " cited report(s), highlighted below"}</span>
            {candidate.proposal_rationale and <span className="text-xs text-muted-foreground">{"Agent rationale (unverified): " + candidate.proposal_rationale}</span>}
        </div>}

        <div className="grid gap-3 md:grid-cols-2">
            <RecordColumn person={personA} label="Record A" cited={cited} />
            <RecordColumn person={personB} label="Record B" cited={cited} />
        </div>

        <div className="grid gap-4 rounded-md border border-border bg-card pt-4 pb-4 pl-4 pr-4 md:grid-cols-3">
            <FactList title="Similarities (rule-based)" items={candidate.reasons} tone="text-status-safe" />
            <FactList title="Differences" items={candidate.differences} tone="text-status-warning" />
            <FactList title="Unknown" items={candidate.unknowns} tone="text-status-neutral" />
        </div>
        <span className="text-xs text-muted-foreground">
            {"ResolveWalker label: " + candidate.confidence + " (count of matching name/age rules, not a probability). Names alone do not establish identity."}
        </span>

        <div className="flex flex-col gap-3 rounded-md border border-border bg-card pt-4 pb-4 pl-4 pr-4">
            <div className="grid gap-3 sm:grid-cols-2">
                <label className="flex flex-col gap-1.5 text-sm">
                    <span className="font-medium">{"Reviewer name"}</span>
                    <input value={reviewer} onChange={lambda (e: ChangeEvent) { reviewer = e.target.value; }}
                        placeholder="e.g. Priya Shah (demo reviewer)"
                        className="h-10 rounded-md border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                </label>
                <label className="flex flex-col gap-1.5 text-sm">
                    <span className="font-medium">{"Reason (optional)"}</span>
                    <input value={note} onChange={lambda (e: ChangeEvent) { note = e.target.value; }}
                        placeholder="What did you check?"
                        className="h-10 rounded-md border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                </label>
            </div>
            {error and <span role="alert" className="text-sm text-destructive">{error}</span>}
            {message and <span role="status" className="text-sm text-status-safe">{message}</span>}
            <div className="flex flex-wrap gap-2">
                <Button disabled={busy != ""} onClick={lambda { submit("CONFIRMED"); }}>
                    <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} />
                    {"Saving..." if busy == "CONFIRMED" else "Confirm same person"}
                </Button>
                <Button variant="outline" disabled={busy != ""} onClick={lambda { submit("REJECTED"); }}>
                    <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
                    {"Saving..." if busy == "REJECTED" else "Reject: different people"}
                </Button>
            </div>
        </div>
    </section>;
}
