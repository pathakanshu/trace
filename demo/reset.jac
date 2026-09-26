"""Delete only the named demo's records; retain shared or unrelated data.
Unknown node types and legacy unscoped activity are deliberately left alone.
"""
import from graph.nodes { Incident, ActivityEntry }
import from graph.edges {
    Involves, Contains, About, Asserts, HasOrganization, Publishes,
    HasSubscription, Receives, LocatedAt, HasSignal
}

def clear_incident(incident_name: str) -> None {
    for incident in [root -->[?:Incident, name == incident_name]] {
        found: dict = {jid(incident): incident};
        for person in [incident ->:Involves:->] {
            found[jid(person)] = person;
            for claim in [person <-:About:<-] {
                if claim.incident_id and claim.incident_id != jid(incident) { continue; }
                found[jid(claim)] = claim;
                for source in [claim <-:Asserts:<-] { found[jid(source)] = source; }
            }
            for sub in [person ->:HasSubscription:->] {
                found[jid(sub)] = sub;
                for alert in [sub ->:Receives:->] { found[jid(alert)] = alert; }
            }
        }
        for org in [incident ->:HasOrganization:->] { found[jid(org)] = org; }
        for media in [incident ->:Contains:->] {
            found[jid(media)] = media;
            for place in [media ->:LocatedAt:->] { found[jid(place)] = place; }
            for signal in [media ->:HasSignal:->] { found[jid(signal)] = signal; }
        }
        for activity in [root -->[?:ActivityEntry]] {
            if activity.incident_id == jid(incident) { found[jid(activity)] = activity; }
        }
        # Root is the persistence anchor, not an external owner. Any other
        # outside relationship protects that node and its outgoing descendants.
        protected: dict = {};
        for key in found {
            record = found[key];
            if key == jid(incident) { continue; }
            incoming = [record <--];
            outgoing = [record -->];
            neighbors = incoming + outgoing;
            for neighbor in neighbors {
                if jid(neighbor) != jid(root) and jid(neighbor) not in found {
                    protected[key] = record;
                }
            }
        }
        frontier: list = list(protected.values());
        while frontier {
            next_frontier: list = [];
            for record in frontier {
                for child in [record -->] {
                    key = jid(child);
                    if key in found and key not in protected and key != jid(incident) {
                        protected[key] = child;
                        next_frontier.append(child);
                    }
                }
            }
            frontier = next_frontier;
        }
        for key in found {
            if key not in protected {
                target = found[key];
                del target;
            }
        }
    }
}
