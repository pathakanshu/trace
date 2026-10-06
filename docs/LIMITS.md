# Current behavior and limits

What each tab does today and what it does not do. Setup is in the [README](../README.md); the Map tab has its own page, [MAP.md](MAP.md).

- Sources (organizations) previews and publishes structured demo reports for an explicit person ID.
  Identical retries return the existing claim; changed content requires a new reference.
- WatchWalker creates in-app alerts from new source claims. Strictly newer dated
  reports are updates; differing latest or undated reports require review.
- People shows sourced timelines and deterministic name/age match candidates.
  Human reviewers can confirm/reject associations with attribution and history.
  Decisions preserve both records and do not merge timelines or change status.
- Map uses bundled Nepal boundaries and graph-backed evidence pins. Reported
  locations are unverified. No street tiles or map API key are needed.
- Media supports image uploads, real SHA-256 copy matching, editable upload details,
  comments, and attributed assertions through the shared snapshot. Seeded checks
  remain simulated. Real EXIF extraction, C2PA, and video analysis are not implemented.
- Graph inspects real node IDs, typed edges, identity reviews, and upload copy links
  from the shared snapshot. Derived/candidate links are labeled. Investigation runs
  appear as Investigation nodes with a stored edge from the incident and derived
  edges to the claims they cite. Media contribution child nodes are not projected.
  A node-link diagram above the list draws the same projection, styled after Jac's
  `/graph` viewer, with live physics written in Jac (no graph library). Records animate
  into a deterministic layout, dragging one pulls its neighbours along, and pressing one
  opens it in the inspector. There is no pan/zoom yet, and the corpus draws only its
  capped 401 records. "Jac's viewer" embeds the runtime's own `/graph` page, which shows
  every node on the server (all incidents). It loads only when chosen.
- People also offers a capped NVIDIA Nemotron check of one source report's
  attribution, with at most one follow-up source comparison. The model returns
  labels only; Jac chooses the next step. Results are advisory, stored separately
  from claims, and unavailable without the server passphrase and key. Each result
  is labeled LIVE (answered now), CACHED (a saved run reused) or REPLAYED (a
  recorded real run re-created on Reset for the two seeded reports), with the
  model id, the original run time and token usage. Offline tests use a mock model;
  label quality rests on the handful of live cases in the investigation guide, not
  on a benchmark.
- No authentication, public publishing, continuous monitoring, or external alert
  delivery. CGX/PFIF import, free-text extraction, broader community workflows, and the
  large planned corpus are not implemented. Retry guarantees are tested sequentially.
