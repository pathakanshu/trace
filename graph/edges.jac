"""Trace graph edges (relationships).

JAC 101: an f"edge" connects two nodes. Declaring f"edge Asserts: Source --> Claim"
tells Jac which node types sit on each end, so a traversal like
f"[source ->:Asserts:->]" is known to return Claim nodes.

Create an edge:   source +>:Asserts():+> claim;
Follow an edge:   [source ->:Asserts:->]     (outgoing)
                  [claim <-:Asserts:<-]      (incoming, i.e. "who asserted this?")

The whole Trace model at a glance:

    Incident -Involves->        Person
    Incident -Contains->        Media
    Source   -Asserts->         Claim
    Claim    -About->           Person
    Claim    -SupportedBy->     Media
    Media    -Depicts->         Person
    Media    -LocatedAt->       Location
    Media    -HasSignal->       VerificationSignal
    Person   -HasSubscription-> Subscription
    Subscription -Receives->    Alert

Agreed additions (see docs/TEAM.md and docs/PUBLISHING.md):

    Incident         -HasOrganization-> Organization (Anshu: demo publishers)
    Organization     -Publishes->       Source       (Anshu: institution behind a report)
    Claim            -Triggered->       Alert        (WatchWalker: which claim caused the alert)
    IdentityDecision -Reviews->         Person       (Gabriel: human review of a pair)
    Media            -ExactCopyOf->     Media        (Aidana: identical SHA-256)
"""

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, Organization, IdentityDecision,
    InvestigationRun
}

edge Involves: Incident --> Person {}

edge Contains: Incident --> Media {}

edge Asserts: Source --> Claim {}

edge About: Claim --> Person {}

edge SupportedBy: Claim --> Media {}

edge Depicts: Media --> Person {}

edge LocatedAt: Media --> Location {}

edge HasSignal: Media --> VerificationSignal {}

edge HasSubscription: Person --> Subscription {}

edge Receives: Subscription --> Alert {}

edge HasOrganization: Incident --> Organization {}
edge Publishes: Organization --> Source {}

edge HasInvestigation: Incident --> InvestigationRun {}

# The claim whose arrival made WatchWalker create this alert.
edge Triggered: Claim --> Alert {
    has walker_name: str = "WatchWalker",
        created_at: str = "";
}

# Human identity review -> each of the two Person records it concerns.
# PROPOSED by Gabriel (People) - schema owner: Miguel.
edge Reviews: IdentityDecision --> Person {}

# The source media is a byte-identical copy of the target (same hash).
# Says nothing about which copy came first.
edge ExactCopyOf: Media --> Media {
    has hash_algo: str = "sha256",
        detected_by: str = "",
        detected_at: str = "";
}
