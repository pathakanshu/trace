"""Demo data for the Bhote Koshi Flood Demo. ALL people and sources are fictional.

seed_demo()  builds the starting graph:
    Incident -> Maya Gurung <- MISSING claim <- Nepal Police Demo
    Maya Gurung -> Subscription (a fictional family member)
    "Maya G." (a possible duplicate record from a community report)
    two media items + a location, checked by EvidenceWalker

clear_demo() deletes only this demo incident’s unshared records.
The hospital FOUND_SAFE claim is NOT seeded - the demo button adds it.
"""

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, ActivityEntry, Organization
}
# NOTE: every edge type you traverse (e.g. f"<-:About:<-") MUST be imported.
import from graph.edges { Involves, Contains, About, Depicts, LocatedAt, HasSubscription, SupportedBy, HasOrganization }
import from demo.reset { clear_incident }
import from walkers.ingest { IngestWalker }
import from walkers.evidence { EvidenceWalker }
import from walkers.watch { WatchWalker }

glob INCIDENT_NAME: str = "Bhote Koshi Flood Demo";
glob PERSON_NAME: str = "Maya Gurung";

# The one scripted update used by the "Add Hospital Update" button.
glob HOSPITAL_UPDATE: dict = {
    "source_name": "Central Hospital Demo",
    "source_type": "HOSPITAL",
    "claim_type": "FOUND_SAFE",
    "claim_value": "Admitted, stable condition",
    "timestamp": "2026-09-21T09:15:00",
    "notes": "Registered at Central Hospital Demo intake desk."
};

# Scope reset to this demo; unrelated incidents and shared nodes survive.
def clear_demo() -> None {
    clear_incident(INCIDENT_NAME);
}

def seed_demo() -> None {
    clear_demo();

    # 1. Police report: Maya is MISSING. IngestWalker builds
    #    Incident -> Person <- Claim <- Source for us.
    root spawn IngestWalker(
        incident_name=INCIDENT_NAME,
        person_name=PERSON_NAME,
        person_age=24,
        source_name="Nepal Police Demo",
        source_type="POLICE",
        claim_type="MISSING",
        claim_value="Last seen near the Bhote Koshi bridge",
        timestamp="2026-09-20T07:40:00",
        notes="Reported missing by family at district police post.",
        source_reference="POLICE-DEMO-001", extraction_method="seeded_fixture"
    );

    # 2. Community report about "Maya G." - maybe the same person, maybe not.
    #    ResolveWalker will flag it; nobody merges it automatically.
    root spawn IngestWalker(
        incident_name=INCIDENT_NAME,
        person_name="Maya G.",
        person_age=24,
        source_name="Community Report Demo",
        source_type="COMMUNITY",
        claim_type="SEEN_AT_LOCATION",
        claim_value="Seen near Tatopani market",
        timestamp="2026-09-20T12:05:00",
        notes="Volunteer relay message, unverified.",
        source_reference="COMMUNITY-DEMO-001", extraction_method="seeded_fixture"
    );

    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    incident.description = "Fictional flash flood along the Bhote Koshi river used for the Trace demo.";
    incident.start_time = "2026-09-20T05:30:00";
    incident.region = "Sindhupalchok, Nepal (demo)";

    incident +>:HasOrganization():+> Organization(name="Central Hospital Demo", organization_type="HOSPITAL");
    incident +>:HasOrganization():+> Organization(name="Flood Relief Demo", organization_type="NGO");

    maya = [p for p in [incident ->:Involves:->] if p.name == PERSON_NAME][0];
    maya.notes = "Fictional demo person.";

    # 3. Someone is watching Maya. WatchWalker alerts land here.
    maya +>:HasSubscription():+> Subscription(
        subscriber_name="Asha Gurung (demo family member)",
        subscriber_contact="asha@example.org"
    );

    # 4. Media + location.
    bridge = Location(name="Bhote Koshi Bridge", latitude=27.9486, longitude=85.9442);
    market = Location(name="Tatopani Market", latitude=27.9612, longitude=85.9391);

    photo = Media(
        media_type="image",
        url="demo/flooded_bridge.jpg",
        captured_at="2026-09-20T07:10:00",
        description="Flooded bridge image",
        exif_gps_present=True,
        community_location="Bhote Koshi Bridge",
        content_hash="img-7f3a"
    );
    video = Media(
        media_type="video",
        url="demo/reposted_flood_video.mp4",
        captured_at="2026-09-20T09:30:00",
        description="Reposted flood video",
        content_hash="vid-22c1"
    );
    video_first = Media(
        media_type="video",
        url="demo/flood_video_earliest.mp4",
        captured_at="2026-09-20T08:02:00",
        description="Flood video (earliest known copy)",
        earliest_known_copy=True,
        content_hash="vid-22c1"
    );
    for m in [photo, video, video_first] {
        incident +>:Contains():+> m;
    }
    photo +>:LocatedAt():+> bridge;
    video +>:LocatedAt():+> market;
    video_first +>:LocatedAt():+> market;
    photo +>:Depicts():+> maya;

    # The police claim points at the bridge photo as supporting media.
    for c in [maya <-:About:<-] {
        if c.claim_type == "MISSING" {
            c +>:SupportedBy():+> photo;
        }
    }

    # 5. Let the agents do their first pass.
    root spawn EvidenceWalker(incident_id=jid(incident));
    root spawn WatchWalker(incident_id=jid(incident));   # marks the seeded claims as already seen
}
