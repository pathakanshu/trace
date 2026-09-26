"""WatchWalker: the heart of the Trace demo.

When new claims arrive about a watched person, it:
  1. walks Incident -> Person
  2. reads every Claim about that person (incoming About edges)
  3. finds claims it has not seen yet
  4. checks whether they change or conflict with the earlier status
  5. walks Person -> Subscription and creates an Alert for each subscriber

Graph path it traverses:

    Incident -Involves-> Person <-About- Claim <-Asserts- Source
                         Person -HasSubscription-> Subscription -Receives-> Alert

It never deletes or overwrites the old claim. Both stay in the graph.
"""

import from graph.nodes { Incident, Person, Claim, Source, Subscription, Alert }
import from graph.edges { Involves, Asserts, About, HasSubscription, Receives }
import from graph.activity { log_activity, now_iso }

# Claim types that describe a person's status (vs e.g. SEEN_AT_LOCATION).
glob STATUS_CLAIMS: list[str] = ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED"];

walker WatchWalker {
    has alerts_created: int = 0;

    can start with Root entry {
        visit [root -->[?:Incident]];
    }

    can to_people with Incident entry {
        visit [here ->:Involves:->];
    }

    can check_person with Person entry {
        # f"<-:About:<-" follows About edges BACKWARDS: "claims about this person".
        claims = [here <-:About:<-];
        # Only people someone is watching matter to this walker.
        subscriptions = [here ->:HasSubscription:->];

        new_claims = [c for c in claims if not c.seen_by_watch];
        old_claims = [c for c in claims if c.seen_by_watch];

        for claim in new_claims {
            claim.seen_by_watch = True;
            if claim.claim_type not in STATUS_CLAIMS {
                continue;
            }
            # Earlier status claims that say something different = update/conflict.
            earlier_types = [
                c.claim_type for c in old_claims
                if c.claim_type in STATUS_CLAIMS and c.claim_type != claim.claim_type
            ];
            if not earlier_types {
                continue;   # first status we have heard, nothing changed
            }
            source_name = self.source_of(claim);
            message = f"New status information for {here.name}: {source_name} reports {claim.claim_type}. Earlier claims ({', '.join(earlier_types)}) are kept.";
            for sub in subscriptions {
                sub +>:Receives():+> Alert(
                    message=message, created_at=now_iso(), severity="high"
                );
                self.alerts_created += 1;
            }
            log_activity(
                "WatchWalker",
                f"Conflicting/updated status for {here.name} ({', '.join(earlier_types)} -> {claim.claim_type}); alerted {len(subscriptions)} subscriber(s)"
            );
        }

        if not new_claims and subscriptions {
            log_activity("WatchWalker", f"No new claims about {here.name}");
        }
    }

    # "Who asserted this claim?" - follow the Asserts edge backwards.
    def source_of(claim: Claim) -> str {
        sources = [claim <-:Asserts:<-];
        return sources[0].name if sources else "Unknown source";
    }
}
