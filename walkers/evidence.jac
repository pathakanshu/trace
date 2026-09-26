"""Evidence checks; exact hash matches are scoped to the same incident."""
import from graph.nodes { Incident, Media, VerificationSignal }
import from graph.edges { Contains, HasSignal }
import from graph.activity { log_activity }
import from features.media.media_upload { IncidentImageUpload }

walker EvidenceWalker {
    has signals_created: int = 0;

    can start with Root entry {
        visit [root -->[?:Incident]];
    }

    can to_media with Incident entry {
        visit [here ->:Contains:->];
    }

    can inspect with Media entry {
        for old in [here ->:HasSignal:->] { del old; }
        if here.exif_gps_present {
            self.add_signal(here, "EXIF_LOCATION", "GPS present", "HIGH",
                "Embedded GPS coordinates are present. They are metadata, not verified ground truth.");
        } else {
            self.add_signal(here, "EXIF_LOCATION", "GPS missing", "UNKNOWN",
                "No GPS metadata. This is not evidence either way.");
        }
        if here.content_hash {
            matches = self.find_duplicates(here);
            if matches {
                self.add_signal(here, "DUPLICATE_MATCH", f"{len(matches)} exact copy/copies",
                    "HIGH", "Identical file bytes were uploaded in this incident. Copies are not independent corroboration.");
            }
        }
        if here.community_location {
            self.add_signal(here, "COMMUNITY_GEOLOCATION", here.community_location, "MEDIUM",
                "Community volunteers matched landmarks. Community input is evidence, not truth.");
        }
        self.add_signal(here, "PROVENANCE", "No C2PA credential", "UNKNOWN",
            "No Content Credentials check is available. Missing credentials do not mean the media is fake.");
        self.add_signal(here, "SYNTHETIC_MEDIA", "Not checked", "NONE",
            "No synthetic-media detector was run.");
        log_activity("EvidenceWalker", f"Checked media for clues: {here.description}");
    }

    def add_signal(media: Media, signal_type: str, value: str, confidence: str, explanation: str) -> None {
        media +>:HasSignal():+> VerificationSignal(
            signal_type=signal_type, value=value, confidence=confidence, explanation=explanation
        );
        self.signals_created += 1;
    }

    def find_duplicates(media: Media) -> list[IncidentImageUpload] {
        found: list[IncidentImageUpload] = [];
        for upload in [root -->][?:IncidentImageUpload] {
            if upload.sha256 == media.content_hash {
                for incident in [root -->[?:Incident]] {
                    if incident.name == upload.incident {
                        found.append(upload);
                    }
                }
            }
        }
        return found;
    }
}
