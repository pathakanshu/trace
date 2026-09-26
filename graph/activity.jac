"""Small shared helpers: current time + the "Agent activity" feed.

Every walker calls f"log_activity(...)" so the UI can show what the agents did.
"""

import from datetime { datetime }
import from graph.nodes { ActivityEntry }

# Current time as a short ISO string, e.g. "2026-09-20T14:30:05".
def now_iso() -> str {
    return datetime.now().isoformat(timespec="seconds");
}

# Attach one ActivityEntry to root. f"root ++> X" connects X to the graph root,
# which is also what makes Jac persist it.
def log_activity(walker_name: str, message: str) -> None {
    root ++> ActivityEntry(
        walker_name=walker_name, message=message, created_at=now_iso()
    );
}
