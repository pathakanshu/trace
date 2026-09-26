"""Trace - entry point.

Top half (server): importing the endpoints here registers them as
POST /function/<name>. Every new def:pub endpoint must be listed here.

Bottom half (client): the router. It holds no state and makes no server calls.
"""

import from services.trace {
    DashboardSnapshot, get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve
}
import from services.geo { get_boundaries }
import from features.media.media_upload { UploadRecord, upload_image, list_image_uploads, check_media_duplicates }

# Explicitly include the generated base so Jac 0.34 copies it into the client
# build. trace-tokens.css also imports it and adds Trace's light/dark tokens.
import ".styles.global.css";
import ".styles.trace-tokens.css";
import from "@jac/runtime" { Router, Routes, Route }
import from .components.TraceDashboard { TraceDashboard }

def:pub app() -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<TraceDashboard />} />
        </Routes>
    </Router>;
}
