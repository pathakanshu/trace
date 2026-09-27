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

# Sequential on purpose: both calls seed an empty store, and running them at
# once created duplicate demo incidents on a fresh preview.
impl TraceDashboard.loadStartup -> None {
    await loadDashboard();
    await loadIncidents();
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
        notice = "Demo reset. Maya Gurung is back to one police report saying she is missing.";
        bannerId = "";
        storyStep = 1;
        activeTab = "Map";
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
        # Read the fresh snapshot here: state set by loadDashboard is not
        # visible inside this handler until the next render.
        fresh = await get_dashboard(incidentId);
        snapshot = fresh;
        notice = "Hospital report added. Trace sent " + str(created) + " alert(s) to people following Maya.";
        if created > 0 and len(fresh.alerts) > 0 {
            bannerId = fresh.alerts[0].id or fresh.alerts[0].created_at;
        }
    } except Exception as e {
        error = "Hospital update failed: " + str(e);
    }
    busy = "";
}

impl TraceDashboard.handleRunWatch -> None {
    busy = "watch";
    try {
        created = await run_watch();
        notice = "Checked for new reports: " + str(created) + " new alert(s).";
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
        notice = "Found " + str(len(found)) + " possible match(es). Nothing was merged.";
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

# Same as handleShowOnMap, but by person: a new claim (the hospital report)
# may have no place of its own, while earlier reports about the person do.
impl TraceDashboard.handleShowPersonOnMap(personId: str) -> None {
    current = snapshot;
    if current is None { return; }
    places = [p for p in current.locations if personId in [e.person_id for e in p.evidence]];
    if not places { return; }
    mapFocusId = places[0].id;
    mapFocusRequest = mapFocusRequest + 1;
    activeTab = "Map";
}

impl TraceDashboard.handleToggleTheme -> None {
    nextDark = not darkMode;
    apply_theme(nextDark);
    darkMode = nextDark;
    try {
        localStorage.setItem("trace-theme", "dark" if nextDark else "light");
    } except Exception {
        return;
    }
}

# A story step only changes the view. Map steps fly to the first place that
# has linked reports (the bridge in the Maya story).
impl TraceDashboard.handleStoryStep(step: int) -> None {
    tab = story_tab(step);
    storyStep = step;
    activeTab = tab;
    current = snapshot;
    if tab == "Map" and current {
        places = [p for p in current.locations if len(p.evidence) > 0];
        if places {
            mapFocusId = places[0].id;
            mapFocusRequest = mapFocusRequest + 1;
        }
    }
}

# The big story button runs the real action; nothing here is simulated.
impl TraceDashboard.handleStoryAction(step: int) -> None {
    if step == 1 {
        activeTab = "People";
        scroll_to_later("panel-People");
    } elif step == 2 {
        activeTab = "People";
        reviewRequest = reviewRequest + 1;
        scroll_to_later("identity-review");
    } elif step == 3 {
        await handleHospitalUpdate();
    } elif step == 4 {
        activeTab = "People";
        investigateRequest = investigateRequest + 1;
        scroll_to_later("report-investigation");
    }
}
