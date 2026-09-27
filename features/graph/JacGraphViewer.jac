"""Jac's own graph visualizer, embedded in the Graph tab (Miguel).

The Jac runtime serves an interactive viewer at /graph on this same server
(vis-network with physics, reading /graph/data). It walks every node reachable
from root, so it shows all incidents, not only this one, and labels nodes by
type. Mount this only when someone asks for it: each mount reads the whole
server graph.
"""

def:pub JacGraphViewer() -> JsxElement {
    return <div className="flex flex-col gap-2">
        <iframe src="/graph" title="Jac's built-in graph visualizer"
            className="h-[70svh] min-h-96 w-full border-0 bg-card" />
        <p className="px-3 pb-3 text-xs text-muted-foreground">
            {"Jac's built-in visualizer, served by the Jac runtime at /graph. It shows every node stored on this server (all incidents), labelled by type. It does not separate stored from derived links and is not linked to the inspector below. "}
            <a href="/graph" target="_blank" rel="noopener noreferrer" className="font-medium text-primary underline underline-offset-2">{"Open it in a new tab"}</a>
        </p>
    </div>;
}
