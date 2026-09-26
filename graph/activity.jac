"""Small shared helpers: current time + the "Agent activity" feed.

Every walker calls f"log_activity(...)" so the UI can show what the agents did.
"""

import from datetime { datetime }
import from graph.nodes { ActivityEntry }

# Current time as a short ISO string, e.g. "2026-09-20T14:30:05".
def now_iso() -> str {
    return datetime.now().isoformat(timespec="seconds");
}

# Claim types stay as codes in the graph (MISSING, FOUND_SAFE...). This turns
# them into words a worried family member would use. The UI has the same map.
glob PLAIN_STATUS: dict[str, str] = {
    "MISSING": "reported missing",
    "FOUND_SAFE": "reported safe",
    "INJURED": "reported injured",
    "DECEASED": "reported deceased",
    "SEEN_AT_LOCATION": "reported seen"
};

def plain_status(claim_type: str) -> str {
    return PLAIN_STATUS.get(claim_type, claim_type.lower().replace("_", " "));
}

# Attach one ActivityEntry to root. f"root ++> X" connects X to the graph root,
# which is also what makes Jac persist it.
def log_activity(walker_name: str, message: str) -> None {
    root ++> ActivityEntry(
        walker_name=walker_name, message=message, created_at=now_iso()
    );
}
