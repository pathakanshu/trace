"""Handler bodies for TraceDashboard.

Inside these f"impl" blocks the component's f"has" fields are used bare
(f"busy = "reset"", not f"self.busy"). Assigning them re-renders the page.

Pattern for every button: set busy -> await server call -> reload snapshot.
"""

impl TraceDashboard.loadDashboard -> None {
    try {
        snapshot = await get_dashboard();
        error = "";
    } except Exception as e {
        error = "Could not load the Trace graph: " + str(e);
    }
    loading = False;
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
