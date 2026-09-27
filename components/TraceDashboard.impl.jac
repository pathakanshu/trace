"""Handler bodies for TraceDashboard.

Inside these f"impl" blocks the component's f"has" fields are used bare
(f"busy = "reset"", not f"self.busy"). Assigning them re-renders the page.

Pattern for every button: set busy -> await server call -> reload snapshot.
"""

impl TraceDashboard.loadDashboard -> None {
    await loadIncidentSnapshot(incidentId);
}

# "" is the Maya demo incident. The id is passed in because a state update made
# in the same handler is not visible until the next render.
impl TraceDashboard.loadIncidentSnapshot(targetId: str) -> None {
    try {
        snapshot = await get_dashboard(targetId);
        error = "";
    } except Exception as e {
        error = "Could not load the Trace graph: " + str(e);
    }
    loading = False;
}

impl TraceDashboard.loadIncidents -> None {
    try {
        incidents = await list_incidents();
    } except Exception as e {
        # The switcher is optional; the demo incident still loads without it.
        incidents = [];
    }
}

impl TraceDashboard.handleSelectIncident(targetId: str) -> None {
    if targetId == incidentId { return; }
    busy = "switch";
    notice = "";
    incidentId = targetId;
    await loadIncidentSnapshot(targetId);
    busy = "";
}

impl TraceDashboard.handleLoadCorpus -> None {
    busy = "corpus";
    try {
        await load_corpus();
        await loadIncidents();
        notice = "Exercise corpus loaded. Choose it in the incident selector.";
    } except Exception as e {
        error = "Loading the exercise corpus failed: " + str(e);
    }
    busy = "";
}

impl TraceDashboard.handleReset -> None {
    busy = "reset";
    try {
        await reset_demo();
        notice = "Demo reset. Maya Gurung is back to a single MISSING claim.";
        await loadDashboard();
    } except Exception as e {
        error = "Reset failed: " + str(e);
    }
    busy = "";
}

impl TraceDashboard.handleHospitalUpdate -> None {
    busy = "hospital";
    try {
        created = await add_hospital_update();
        notice = "IngestWalker added the Central Hospital claim. WatchWalker created " + str(created) + " alert(s).";
        await loadDashboard();
    } except Exception as e {
        error = "Hospital update failed: " + str(e);
    }
    busy = "";
}

impl TraceDashboard.handleRunWatch -> None {
    busy = "watch";
    try {
        created = await run_watch();
        notice = "WatchWalker finished: " + str(created) + " new alert(s).";
        await loadDashboard();
    } except Exception as e {
        error = "WatchWalker failed: " + str(e);
    }
    busy = "";
}

impl TraceDashboard.handleRunResolve -> None {
    busy = "resolve";
    try {
        found = await run_resolve();
        notice = "ResolveWalker found " + str(len(found)) + " potential duplicate(s). Nothing was merged.";
        await loadDashboard();
    } except Exception as e {
        error = "ResolveWalker failed: " + str(e);
    }
    busy = "";
}

# Keyboard navigation follows the same in-place state change as a mouse click.
impl TraceDashboard.handleTabKey(event: any, index: int) -> None {
    nextIndex = index;
    if event.key == "ArrowRight" {
        nextIndex = (index + 1) % len(DASHBOARD_TABS);
    } elif event.key == "ArrowLeft" {
        nextIndex = (index + len(DASHBOARD_TABS) - 1) % len(DASHBOARD_TABS);
    } elif event.key == "Home" {
        nextIndex = 0;
    } elif event.key == "End" {
        nextIndex = len(DASHBOARD_TABS) - 1;
    } else {
        return;
    }
    event.preventDefault();
    nextTab = DASHBOARD_TABS[nextIndex];
    activeTab = nextTab;
    target: any = document.getElementById("tab-" + nextTab);
    if target { target.focus(); }
}

# Navigation resolves real claim/location links in the current shared snapshot.
# A counter allows revisiting the same report after panning elsewhere.
impl TraceDashboard.handleShowOnMap(claimId: str) -> None {
    current = snapshot;
    if current is None { return; }
    locations = current.locations;
    places = [p for p in locations if claimId in [e.claim_id for e in p.evidence]];
    if not places { return; }
    mapFocusId = places[0].id;
    mapFocusRequest = mapFocusRequest + 1;
    activeTab = "Map";
    target: any = document.getElementById("tab-Map");
    if target { target.focus(); }
}
