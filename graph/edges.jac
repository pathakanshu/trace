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
"""

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, Organization
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
