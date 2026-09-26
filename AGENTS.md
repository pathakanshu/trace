# Working on Trace (for AI coding agents)

Trace is a Jac 0.34 full-stack app. Read `README.md` first. Consult the bundled Jac guides before writing Jac: `jac guide jac-core-cheatsheet`, `jac guide jac-walker-patterns`, `jac guide jac-node-edge-patterns`.

## Layout
- `graph/` node + edge definitions (the schema). `walkers/` graph agents. `demo/seed.jac` demo data.
- `services/trace.jac` holds the `def:pub` endpoints and the `obj` view types sent to the UI.
- `components/TraceDashboard.jac` owns state; handler bodies are in `TraceDashboard.impl.jac`; panels in `DashboardPanels.jac`.
- `components/ui/` holds shadcn primitives. Never edit them; add new ones with `jac install --shadcn <name>`.

## Rules that bite
- Import EVERY edge type you traverse (`[x <-:About:<-]` needs `About` imported), or the filter silently matches all edges.
- New `def:pub` endpoint: also add its name to the import in `main.jac`.
- Client code: `sv import from ..services.trace { ... }` and always `await` calls.
- `has` fields: required ones before defaulted ones.
- Server/graph changes may need a preview restart; stale data: delete `.jac/data/`.
- Run `jac check <file>` and `jac test tests/test_trace.jac` after changes.

## Domain rules (do not break)
- Person has no status field. Status = Claim nodes with a Source.
- Never delete or overwrite old claims. Never auto-merge people.
- No single "truth score". Signals are independent evidence with explanations.
- Say "earliest known copy", never "original". Fictional data only.

## Scope
This is a hackathon starter. Keep files small and code readable, and add comments for Jac-specific syntax.
