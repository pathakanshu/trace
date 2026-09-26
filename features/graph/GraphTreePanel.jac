"""Record inspector for the Graph tab (Miguel).

Shows one stored record: its jid, fields, provenance, and every typed edge
into and out of it. Clicking an edge selects the record at the other end.
Pure presentation over the GraphSnapshot projection; holds no data of its own.
"""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { InformationCircleIcon, ArrowRight01Icon, ArrowLeft01Icon }
import from ...components.shared.Display { EmptyPanel, friendly_time }
import from ...lib.utils { cn }
import from .graph_helpers { edge_phrase, badge_tone, badge_hint, short_id }
sv import from .services { GraphSnapshot, GraphNodeView, GraphEdgeView, GraphField }

def:pub ProvenanceBadge(badge: str) -> JsxElement {
    return <span title={badge_hint(badge)}
        className={cn("inline-flex items-center rounded-sm border px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide", badge_tone(badge))}>
        {badge}
    </span>;
}

def:pub FieldList(title: str, items: list[GraphField]) -> JsxElement {
    return <section className="flex flex-col gap-2">
        <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h4>
        {if len(items) == 0 {
            <p className="text-sm text-muted-foreground">{"Nothing recorded."}</p>
            skip;
        }}
        <dl className="grid grid-cols-1 gap-x-4 gap-y-1.5 text-sm sm:grid-cols-[minmax(0,10rem)_minmax(0,1fr)]">
            {for f in items {
                <div key={f.name} className="contents">
                    <dt className="font-mono text-xs text-muted-foreground sm:pt-0.5">{f.name}</dt>
                    <dd className={cn("min-w-0 break-words", "text-muted-foreground italic" if f.value == "not recorded" else "")}>{f.value}</dd>
                </div>
            }}
        </dl>
    </section>;
}

def:pub EdgeRow(
    link: GraphEdgeView, other: GraphNodeView | None, outgoing: bool,
    selfLabel: str, onSelect: Callable[[str], None]
) -> JsxElement {
    other_id = link.to_id if outgoing else link.from_id;
    other_label = other.label if other else "Record outside this incident";
    other_kind = other.kind if other else "Unknown";
    def handle_click(e: MouseEvent) {
        if other { onSelect(other_id); }
    }
    return <li className={cn("rounded-md border bg-background", "border-dashed" if link.derived else "border-border")}>
        <button type="button" onClick={handle_click} disabled={not other}
            className="flex w-full flex-col gap-1.5 p-3 text-left transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-60">
            <div className="flex flex-wrap items-center gap-2">
                <HugeiconsIcon icon={ArrowRight01Icon if outgoing else ArrowLeft01Icon} strokeWidth={2} className="size-4 text-muted-foreground" />
                <span className="font-mono text-xs font-semibold text-primary">{link.kind}</span>
                <ProvenanceBadge badge={link.status} />
            </div>
            <p className="text-sm">
                {(selfLabel + " " + edge_phrase(link.kind) + " ") if outgoing else ""}
                <span className="font-medium">{other_label}</span>
                {"" if outgoing else (" " + edge_phrase(link.kind) + " this record")}
            </p>
            <span className="font-mono text-[11px] text-muted-foreground">{other_kind + " " + short_id(other_id)}</span>
            {len(link.fields) > 0 and <span className="text-xs text-muted-foreground">
                {", ".join([f.name + ": " + f.value for f in link.fields])}
            </span>}
        </button>
    </li>;
}

def:pub RecordInspector(
    graph: GraphSnapshot, record: GraphNodeView | None, onSelect: Callable[[str], None]
) -> JsxElement {
    if record == None {
        return <EmptyPanel icon={InformationCircleIcon} title="Select a record"
            text="Pick any record on the left to see its fields, where it came from, and how it connects." />;
    }
    rid = record.id;
    by_id: dict[str, GraphNodeView] = {};
    for n in graph.nodes { by_id[n.id] = n; }
    outgoing = [e for e in graph.edges if e.from_id == rid];
    incoming = [e for e in graph.edges if e.to_id == rid];

    return <article className="flex flex-col gap-5 rounded-lg border border-border bg-card p-4 shadow-sm md:p-5">
        <header className="flex flex-col gap-2 border-b border-border pb-4">
            <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-sm bg-primary/15 px-2 py-0.5 text-xs font-semibold text-primary">{record.kind}</span>
                {for b in record.badges { <ProvenanceBadge key={b} badge={b} /> }}
            </div>
            <h3 className="font-display text-xl leading-snug break-words">{record.label}</h3>
            <p className="font-mono text-xs break-all text-muted-foreground">{"jid " + rid}</p>
        </header>
        <div className="grid gap-5 lg:grid-cols-2">
            <FieldList title="Fields" items={record.fields} />
            <FieldList title="Provenance" items={record.provenance} />
        </div>
        <section className="flex flex-col gap-2">
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{"Outgoing relationships (" + str(len(outgoing)) + ")"}</h4>
            {if len(outgoing) == 0 { <p className="text-sm text-muted-foreground">{"No outgoing edges."}</p> skip; }}
            <ul className="flex flex-col gap-2">
                {for e in outgoing {
                    <EdgeRow key={e.id} link={e} other={by_id.get(e.to_id)} outgoing={True} selfLabel={record.label} onSelect={onSelect} />
                }}
            </ul>
        </section>
        <section className="flex flex-col gap-2">
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{"Incoming relationships (" + str(len(incoming)) + ")"}</h4>
            {if len(incoming) == 0 { <p className="text-sm text-muted-foreground">{"No incoming edges."}</p> skip; }}
            <ul className="flex flex-col gap-2">
                {for e in incoming {
                    <EdgeRow key={e.id} link={e} other={by_id.get(e.from_id)} outgoing={False} selfLabel={record.label} onSelect={onSelect} />
                }}
            </ul>
        </section>
    </article>;
}
