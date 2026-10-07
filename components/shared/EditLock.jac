"""Unlock control for a deploy that locks writes (see services/access.jac).

The passphrase is kept for this browser tab only and sent with each write; the
server checks it every time. Nothing renders on a server that locks nothing.
"""
import from ..ui.button { Button }
sv import from ...services.access { editing_access }

# A refused call that raises reaches the browser as the whole error response.
# Show only the lock message in that case.
cl def:pub write_error(e: any) -> str {
    text = str(e);
    if "Editing is locked" in text {
        return "Editing is locked on this public site. Enter the team passphrase under Unlock editing at the bottom of the page.";
    }
    return text;
}

# Explicit cl keeps this a browser helper when feature tabs import it.
cl def:pub edit_key() -> str {
    try {
        return sessionStorage.getItem("trace-edit-key") or "";
    } except Exception {
        return "";
    }
}

def:pub EditLock() -> JsxElement {
    has locked: bool = False, unlocked: bool = False, entering: bool = False,
        value: str = "", busy: bool = False, error: str = "";

    # "yes", "no", or "failed" when the server could not be asked.
    async def check(key: str) -> str {
        try {
            access = await editing_access(key);
            locked = access.locked;
            unlocked = access.locked and access.allowed;
            return "yes" if access.allowed else "no";
        } except Exception {
            return "failed";
        }
    }
    async def unlock -> None {
        busy = True;
        error = "";
        answer = await check(value);
        if answer == "yes" {
            try {
                sessionStorage.setItem("trace-edit-key", value);
                value = "";
                entering = False;
            } except Exception {
                # Writes read the key from tab storage, so without it nothing is unlocked.
                unlocked = False;
                error = "This browser blocks tab storage, so editing cannot be unlocked here.";
            }
        } elif answer == "no" {
            error = "That passphrase was not accepted.";
        } else {
            error = "The server could not be reached. Try again.";
        }
        busy = False;
    }
    def lock -> None {
        try { sessionStorage.removeItem("trace-edit-key"); } except Exception { error = ""; }
        unlocked = False;
    }

    can with entry {
        check(edit_key());
    }

    if not locked { return <span />; }
    if unlocked {
        return <span className="flex items-center gap-2">
            {"Editing unlocked in this tab."}
            <Button variant="ghost" size="sm" onClick={lock}>{"Lock"}</Button>
        </span>;
    }
    return <span className="flex flex-wrap items-center gap-2">
        {"Publishing, imports and media changes are locked on this public site."}
        {not entering and <Button variant="ghost" size="sm" onClick={lambda { entering = True; }}>{"Unlock editing"}</Button>}
        {entering and <input type="password" autoComplete="off" aria-label="Team passphrase" value={value} disabled={busy}
            onChange={lambda (e: any) { value = e.target.value; }}
            className="rounded-md border border-input bg-card p-1.5 text-foreground" />}
        {entering and <Button variant="outline" size="sm" disabled={busy or not value} onClick={unlock}>{"Unlock"}</Button>}
        {error and <span role="alert" className="text-destructive">{error}</span>}
    </span>;
}
