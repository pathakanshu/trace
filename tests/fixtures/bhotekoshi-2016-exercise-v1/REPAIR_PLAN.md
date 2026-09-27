# Private corpus repair and integration handoff

This file is evaluator/developer guidance. Never load it into application inputs,
retrieval, model prompts, indexes or client responses. All people, institutions,
reports and media are fictional exercise material. The workload is not a count
of historical missing people.

## What is available now

- `origin/codex/test-data`: 8,027 primary records, including 1,150 Person records
  representing 1,000 private identities, 1,800 sources, 3,600 claims, 32
  organizations, 200 media records and only 170/1,000 required locations.
- Hero selection: `tests/fixtures/bhotekoshi-2016-exercise-v1/hero/`, 658 exact
  full-catalog records: 62 Person, 304 claims, 125 sources, 40 media, 54 locations,
  one incident and required supporting records. It now has complete reference
  closure. A scenario ID in its manifest does not mean the story is executable.
- Contract-shaped private identity labels preserve all IDs, membership and ages.
  Initial locations are 50 existing points and 950 unknowns; this is incomplete
  geography, not an inferred location for absent reports.
- 40 concrete negative inputs and 40 distinct research questions with actual
  claim/source citations and release cutoffs. No generated answers.
- Separate reset-control inputs: 26 records (two incidents, ten people, two
  organizations, two sources, ten claims), reserved IDs 900001+, excluded from
  primary counts. Control reset has not run in the application.
- Release `bhotekoshi-2016-exercise-v1-preview`: unchanged ZIP, 200 dummy images
  and 200 thumbnails. SHA-256:
  `00629b3cc4b832e092f206b54f15c57d438e124dfaca97b904b4c1a21d8a444b`.
  The actual bundle was restored twice into a fresh temporary checkout; both
  runs verified 400 files and the repeat preserved bytes/modification times.

## Measured defects that block claiming a complete corpus

| Area | Actual finding | Required repair/check |
| --- | --- | --- |
| Geography | 170 locations; four verified current settlement anchors, no approved sampling zones/area polygons | Obtain cited geographic inputs, preserve downloaded bytes/checksums, implement the specified sampler; never invent the remaining 830 paths/points |
| Final status cohorts | T+72 is 353 missing / 547 safe / 50 injured / 50 unresolved under private fixture recomputation | The 300 depth reports assign 297 new safe outcomes outside the intended cohort; reconcile source history with the 650/250/50/50 targets |
| Rumor uncertainty | Six of ten death-rumor claims lack available equal-time or unknown-time opposing status | Supply actual attributed opposing evidence/challenges; keep every rumor unconfirmed |
| Release dependencies | 153 references point to later records | Repair release batches or an explicitly agreed representation; importer ordering alone cannot expose future information |
| Raw JSON reports | 1,260 old envelopes fail the specified publisher/reference/content/entries shape | Coordinate a provenance-preserving conversion/adapter; all 1,800 existing raw hashes match and originals must remain intact |
| Identity benchmark | All 165 positive/85 negative labels and citations are correct, but 20 same-name/age negatives have indistinguishable supplied context | Supply attributed distinguishing evidence; do not score forced rejections from private labels alone |
| Votes | 360 self-votes; 120 duplicate contributor/contribution pairs | Use distinct attributable non-author voters, one vote per pair, while retaining 240 helpful/120 not-helpful coverage |
| Tasks | 36 submissions target different records from their tasks; reviewed snapshots lack cited claim evidence | Link actual appropriate contributions, reviewer evidence and times; do not claim that fixture snapshots are executed reviews |
| Subscriptions | Maximum one distinct active follower on a hero Person | Cover two followers on one hero Person, no-follower person and mixed subject follows; test alerts only through actual execution |
| Support files | Legacy manifest/license/checkpoint/scenario/action/report shapes | Migrate consumers together, populate real nested references and generated checksums; exact shape alone is insufficient |
| Story focus | Shelter story points to TREATMENT fac-000001; correction/translation stories select COMMENT con-000031/con-000061; historical scenario points to media-caption clm-001151 | Reconcile narratives, typed focal records and cited actions while preserving the 50-identity hero quota |
| Runtime | No compatible full-corpus importer/replay runner has been invoked | Explicit supported/deferred/rejected mappings, real persistence/retry/reset/alert traces, twice-reset rehearsal, then another laptop |

The diagnostic summary algorithm uses private identity grouping, latest known
observation-time status plus undated competing statuses, and keeps death rumors
unresolved. It is not application summary logic, a human identity decision or a
verification result. All other reported failures are calculated from actual files.
The unit tests intentionally detect known bad fixture cases; passing tooling
unit tests does **not** make the corpus audit pass.

## Coordinate before rewriting published records

The preview and its original sources have already been distributed. Do not run
`generate_catalog.py` or the legacy validator to silently overwrite them, their
hashes, or support files. Existing generator functions still contain the defects
above; only query/negative/hero generation has been independently repaired.

Before a corpus-wide repair, agree with Anshu and Miguel how immutable originals,
stable IDs, namespace/version and exact quotas will coexist. Appending corrective
sources changes quota counts; replacing authored source bytes under the same
identity loses history. A new dataset namespace or an explicitly documented
correction extension needs coordination. Preserve the preview release and old
input bytes. Record the decision in STATUS and this handoff before mutation.
No contract or application schema was changed by the audit work.

## Integration order

1. Fetch `codex/test-data` in a separate checkout and restore the checksum-verified
   asset ZIP with `tools/test_data/unpack_assets.py`.
2. Run `python3 tools/test_data/audit_contracts.py`. Its current nonzero exit is
   expected for measured defects, not an environmental failure. Read every
   failed/blocked check in `contract-audit.json`.
3. Use public catalog rows/raw inputs/assets only. Hero rows are exact selections
   from that catalog; exclude its manifest and all private oracle/query/negative/
   replay expectations from application ingestion. Never expose private grouping.
4. Define supported kinds/fields and provenance mappings with graph owners. Keep
   source publication, observation, release and real ingestion times distinct.
   Never convert unsupported data to generic notes or fake successful checks.
5. Implement isolated fixture-ID mappings and incident reset; keep the two control
   incidents and explicitly shared records intact. Stage all IDs, resolve typed
   references, apply release cutoffs, and fail on unhandled dependencies.
6. Exercise actual hero actions and report real outputs/errors. Validate source
   immutability, matching review provenance, alert idempotence, persisted reload
   and two resets before scaling. Existing small-app tests do not validate this
   corpus. Keep optional video work deferred.

The exact documented support contracts and quotas remain the source of truth;
this handoff records gaps and an integration sequence, not new runtime APIs.
