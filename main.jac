"""Trace - entry point.

Top half (server): importing the endpoints here registers them as
POST /function/<name>. Every new def:pub endpoint must be listed here.

Bottom half (client): the router. It holds no state and makes no server calls.
"""

import from services.trace {
    DashboardSnapshot, get_dashboard, reset_demo, add_hospital_update, run_watch, run_resolve,
    IncidentOption, PlaceCount, list_incidents, search_people
}
import from demo.corpus { load_corpus }
import from services.timeline { TimelineEntry, person_timeline }
import from services.geo { get_boundaries, get_bhotekoshi_corridor, get_nepal_rivers }
import from features.organizations.services { publish_report }
import from features.organizations.pfif { PfifResult, import_pfif }
import from services.investigation { investigate_report }
import from services.access { EditingAccess, editing_access }
# People (Gabriel): human identity review.
import from features.people.services { review_identity, propose_identity, IdentityDecisionResult }
import from features.media.media_upload { UploadRecord, upload_image, list_image_uploads, list_incident_media, check_media_duplicates, edit_media, delete_media, add_media_comment, add_media_assertion }

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
