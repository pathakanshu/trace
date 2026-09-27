"""Inspect exact incident-scoped media copies and attributed location/source claims."""
import from graph.nodes { Incident, Media, VerificationSignal }
import from graph.edges { Contains, HasSignal }
import from graph.activity { log_activity }
import from features.media.media_upload { MediaMetadata, MediaAssertion }

walker EvidenceWalker {
    has signals_created: int = 0;

    can start with Root entry { visit [root -->[?:Incident]]; }
    can to_media with Incident entry { visit [here ->:Contains:->]; }

    can inspect with Media entry {
        if here.content_hash {
            self.set_signal(here, "DUPLICATE_MATCH", self.duplicate_summary(here),
                "HIGH", "Exact byte-hash matches are copies, not independent corroboration.");
        }
        assertions = [child for child in [here -->][?:MediaAssertion]];
        if assertions {
            repeated: list[str] = [];
            unique: list[str] = [];
            for assertion in assertions {
                key = assertion.assertion_type + "|" + assertion.value.strip().lower();
                if key in unique { repeated.append(key); }
                else { unique.append(key); }
            }
            summary = str(len(assertions)) + " sourced media claim(s); " + str(len(repeated)) + " repeated assertion(s).";
            self.set_signal(here, "LOCATION_SOURCE_CLAIMS", summary, "UNKNOWN",
                "Claims retain their sources and timestamps. They are reports, not verified ground truth.");
        }
        log_activity("EvidenceWalker", "Inspected exact media copies and sourced claims.");
    }

    def duplicate_summary(media: Media) -> str {
        incident = self.incident_for(media);
        if incident is None { return "Exact SHA-256 matching is available for uploaded records."; }
        hashes: list[str] = [];
        media_meta = self.get_meta(media);
        digest = media_meta.sha256 if media_meta else media.content_hash;
        for candidate in [incident ->:Contains:->] {
            candidate_meta = self.get_meta(candidate);
            candidate_hash = candidate_meta.sha256 if candidate_meta else candidate.content_hash;
            if jid(candidate) != jid(media) and digest and candidate_hash == digest { hashes.append(jid(candidate)); }
        }
        return str(len(hashes)) + " exact matching media record(s).";
    }

    def get_meta(media: Media) -> MediaMetadata | None {
        for meta in [media -->][?:MediaMetadata] { return meta; }
        return None;
    }

    def incident_for(media: Media) -> Incident | None {
        for incident in [root -->][?:Incident] {
            for item in [incident ->:Contains:->] {
                if jid(item) == jid(media) { return incident; }
            }
        }
        return None;
    }

    def set_signal(media: Media, signal_type: str, value: str, confidence: str, explanation: str) {
        existing = [signal for signal in [media ->:HasSignal:->]
            if signal.signal_type == signal_type];
        if existing {
            existing[0].value = value;
            existing[0].confidence = confidence;
            existing[0].explanation = explanation;
        } else {
            media +>:HasSignal():+> VerificationSignal(
                signal_type=signal_type, value=value, confidence=confidence, explanation=explanation
            );
            self.signals_created += 1;
        }
    }
}
