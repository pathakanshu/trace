"""EvidenceWalker: attach verification signals to media.

Each signal is ONE independent piece of evidence with its own confidence and
explanation. There is deliberately no combined "truth score".

Honesty rules baked in:
  - no C2PA credential does NOT mean fake
  - duplicate match finds the "earliest known copy", NOT the original creator

FUTURE (Person 3): replace the demo fields with real checks - EXIF parsing,
perceptual hashing, C2PA / Content Credentials - each producing more
VerificationSignal nodes through f"add_signal".
"""

import from graph.nodes { Incident, Media, VerificationSignal }
import from graph.edges { Contains, HasSignal }
import from graph.activity { log_activity }

walker EvidenceWalker {
    has signals_created: int = 0, incident_id: str = "", current_incident_id: str = "";

    can start with Root entry {
        visit [i for i in [root -->[?:Incident]] if not self.incident_id or jid(i) == self.incident_id];
    }

    # From each incident, walk to every Media it contains.
    can to_media with Incident entry {
        self.current_incident_id = jid(here);
        visit [here ->:Contains:->];
    }

    can inspect with Media entry {
        # Re-running should not duplicate signals: clear old ones first.
        for old in [here ->:HasSignal:->] {
            del old;
        }

        if here.exif_gps_present {
            self.add_signal(here, "EXIF_LOCATION", "GPS present", "HIGH",
                "Embedded GPS coordinates match the reported area.");
        } else {
            self.add_signal(here, "EXIF_LOCATION", "GPS missing", "UNKNOWN",
                "No GPS metadata. Common for reposted media; not evidence either way.");
        }

        if here.community_location {
            self.add_signal(here, "COMMUNITY_GEOLOCATION", here.community_location, "MEDIUM",
                "Community volunteers matched landmarks. Community input is evidence, not truth.");
        }

        if here.content_hash {
            others = self.find_duplicates(here);
            if others {
                self.add_signal(here, "DUPLICATE_MATCH", f"{len(others)} matching cop(ies)", "HIGH",
                    "Same content hash seen elsewhere. The earliest known copy is not necessarily the original.");
            }
        }

        self.add_signal(here, "PROVENANCE", "No C2PA credential", "UNKNOWN",
            "No Content Credentials found. Missing credentials do not mean the media is fake.");
        self.add_signal(here, "SYNTHETIC_MEDIA", "No signal available", "NONE",
            "No synthetic-media detector was run in the starter.");

        log_activity("EvidenceWalker", f"Simulated evidence checks: {here.description}", self.current_incident_id);
    }

    def add_signal(media: Media, signal_type: str, value: str, confidence: str, explanation: str) -> None {
        media +>:HasSignal():+> VerificationSignal(
            signal_type=signal_type, value=value,
            confidence=confidence, explanation=explanation
        );
        self.signals_created += 1;
    }

    # Other media in any incident sharing the same content hash.
    def find_duplicates(media: Media) -> list[Media] {
        found: list[Media] = [];
        for incident in [root -->[?:Incident]] {
            for m in [incident ->:Contains:->] {
                if jid(m) != jid(media) and m.content_hash == media.content_hash {
                    found.append(m);
                }
            }
        }
        return found;
    }
}
