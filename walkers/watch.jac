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
import from graph.activity { log_activity, now_iso, plain_status }

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
            earlier_words = " and ".join([plain_status(t) for t in earlier_types]);
            message = f"Update on {here.name}: {source_name} has {plain_status(claim.claim_type)}. Earlier they were {earlier_words}. Both reports are shown so you can see who said what.";
            for sub in subscriptions {
                sub +>:Receives():+> Alert(
                    message=message, created_at=now_iso(), severity="high"
                );
                self.alerts_created += 1;
            }
            log_activity(
                "WatchWalker",
                f"Noticed new information about {here.name} and notified {len(subscriptions)} " + ("person" if len(subscriptions) == 1 else "people") + " following them"
            );
        }

        if not new_claims and subscriptions {
            log_activity("WatchWalker", f"Checked for updates on {here.name}: nothing new");
        }
    }

    # "Who asserted this claim?" - follow the Asserts edge backwards.
    def source_of(claim: Claim) -> str {
        sources = [claim <-:Asserts:<-];
        return sources[0].name if sources else "Unknown source";
    }
}
