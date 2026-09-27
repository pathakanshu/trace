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

import from graph.nodes { Incident, Media, VerificationSignal, MediaMetadata, MediaAssertion }
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
        metadata = [here -->][?:MediaMetadata];
        if metadata {
            self.inspect_upload(here, metadata[0]);
            return;
        }
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

    def inspect_upload(media: Media, metadata: MediaMetadata) -> None {
        matches = 0;
        incidents = [i for i in [root -->[?:Incident]] if jid(i) == self.current_incident_id];
        if not incidents { return; }
        for other in [incidents[0] ->:Contains:->] {
            other_metadata = [other -->][?:MediaMetadata];
            if jid(other) != jid(media) and other_metadata and other_metadata[0].sha256 == metadata.sha256 {
                matches += 1;
            }
        }
        self.set_signal(media, "DUPLICATE_MATCH", str(matches) + " exact matching media record(s).",
            "HIGH", "SHA-256 of uploaded bytes within this incident. Copies are not independent corroboration.", "sha256");
        assertions = [media -->][?:MediaAssertion];
        unique: list[str] = [];
        repeated = 0;
        for assertion in assertions {
            key = assertion.assertion_type + "|" + assertion.value.strip().lower();
            if key in unique { repeated += 1; }
            else { unique.append(key); }
        }
        if assertions {
            self.set_signal(media, "LOCATION_SOURCE_CLAIMS", str(len(assertions)) + " sourced media claim(s); " + str(repeated) + " repeated assertion(s).",
                "UNKNOWN", "Attributed reports retain their sources and timestamps; they are not verified location facts.", "reported");
        }
        log_activity("EvidenceWalker", "Inspected uploaded bytes and sourced claims.", self.current_incident_id);
    }

    def set_signal(media: Media, signal_type: str, value: str, confidence: str, explanation: str, method: str) -> None {
        existing = [signal for signal in [media ->:HasSignal:->] if signal.signal_type == signal_type and signal.method == method];
        if existing {
            existing[0].value = value;
            existing[0].confidence = confidence;
            existing[0].explanation = explanation;
        } else {
            media +>:HasSignal():+> VerificationSignal(signal_type=signal_type, value=value,
                confidence=confidence, explanation=explanation, method=method);
            self.signals_created += 1;
        }
    }

    # Other seeded media in the current incident sharing the fixture hash.
    def find_duplicates(media: Media) -> list[Media] {
        found: list[Media] = [];
        for incident in [i for i in [root -->[?:Incident]] if jid(i) == self.current_incident_id] {
            for m in [incident ->:Contains:->] {
                if jid(m) != jid(media) and m.content_hash == media.content_hash {
                    found.append(m);
                }
            }
        }
        return found;
    }
}
