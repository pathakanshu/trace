"""Who may write to the graph on a public deploy.

The site is open for anyone to read. Publishing reports, importing PFIF and
changing media put visitor-supplied content in front of every other visitor,
so a deploy that sets TRACE_LIVE_PASSPHRASE requires it for those calls. With
the variable unset (local work and tests) nothing is locked.

The Jac server logs each call's parameters, so the passphrase appears in the
server log, as it already does for live model checks. Treat that log as private.
"""
import os;
import hmac;

glob LOCKED_MESSAGE: str = "Editing is locked on this public site. Enter the team passphrase under Unlock editing at the bottom of the page.";

# Stripped on both sides: a stray space or newline in the deploy setting must
# neither lock the site with a passphrase nobody can type nor count as one.
def expected_passphrase() -> str {
    return os.environ.get("TRACE_LIVE_PASSPHRASE", "").strip();
}

"""Why a write may not happen, or "" when it may."""
def write_gate(passphrase: str) -> str {
    expected = expected_passphrase();
    if not expected { return ""; }
    try {
        given = str(passphrase).strip().encode();
    } except UnicodeError {
        return LOCKED_MESSAGE;
    }
    if hmac.compare_digest(given, expected.encode()) { return ""; }
    return LOCKED_MESSAGE;
}

# Raises so each endpoint can refuse before it reads or changes anything.
def require_write(passphrase: str) -> None {
    blocked = write_gate(passphrase);
    if blocked { raise ValueError(blocked); }
}

obj EditingAccess {
    has locked: bool = False, allowed: bool = True;
}

"""locked: this server asks for a passphrase. allowed: the one given opens it."""
def:pub editing_access(passphrase: str = "") -> EditingAccess {
    locked = expected_passphrase() != "";
    return EditingAccess(locked=locked, allowed=write_gate(passphrase) == "");
}
