"""Trace - entry point.

Top half (server): importing the endpoints here registers them as
POST /function/<name>. Every new def:pub endpoint must be listed here.

Bottom half (client): the router. It holds no state and makes no server calls.
"""

import from services.trace {
    DashboardSnapshot, get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve
}

import ".styles.global.css";
import from "@jac/runtime" { Router, Routes, Route }
import from .components.TraceDashboard { TraceDashboard }

def:pub app() -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<TraceDashboard />} />
        </Routes>
    </Router>;
}
