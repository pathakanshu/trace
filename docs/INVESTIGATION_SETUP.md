# Run the budgeted Jev investigation

Use the official TypeSafe API for semantic checks and keep graph retrieval,
calculation, source storage, and presentation in Jac. No local model download,
additional AI subscription, or generative summary model is required for this slice.

## Cost and limits

TypeSafe publishes `jev-1.13.0` at **$0.042 / million input tokens**, with free
output, checked September 26, 2026. See the
[official model page](https://docs.typesafe.ai/models). An API key is a credential;
the provider charges for usage. Check the official console's current credit and
payment requirements before adding funds. Do not buy more than $10 of credit.

At an assumed 4,000 input tokens per call (evidence plus questions):

| Cases | Calls per case | Estimated model cost |
| --- | --- | --- |
| 1,000 | 2 | $0.336 |
| 5,000 | 2 | $1.68 |
| 10,000 | 2 | $3.36 |

These estimates exclude retries and other use of the account. Actual tokens are
recorded in each accepted provider result. The code sends at most two requests
per selected-report check and never runs a paid call on dashboard refresh.

- Default lifetime application allowance: **$1** for this working directory.
- `TRACE_JEV_BUDGET_USD` can increase that allowance to at most **$8**.
- Before each request, reserve the published maximum input size (64,000 tokens,
  $0.002688 at the pinned rate). Reconcile to validated actual input usage after
  success; a timeout or malformed response keeps the full reservation.
- No automatic retries. An explicit retry must pass the guard again.
- `.trace-local/jev-spending.json` is the ignored, persistent operational ledger.
  Demo reset and Jac build cleanup do not reset it. Do not delete it to unblock
  spending. A corrupted existing ledger stops calls and needs reconciliation.
- A file lock prevents workers sharing this directory from spending concurrently.
  Successful investigations are also cached in the graph by evidence fingerprint.
- This is an application guard, **not an account-wide billing limit**. Separate
  clones/deployments and teammates using the same key have separate ledgers. Use
  one inference host for the team; account for any outside usage separately and
  enable a provider-side spending cap if the console offers one. Recheck the
  price before changing the model. Taxes or provider payment minimums are separate.

## Start locally

Use the working Jac 0.34.1 binary described in [README](../README.md). Stop the
old app server first if it occupies port 8017; do not run two copies against the
same graph store. Run the following from the project directory.

In zsh, enter the key privately at the prompt (it is not echoed or put into the
command itself):

```sh
read -s "TYPESAFE_API_KEY?Paste TypeSafe API key: "
export TYPESAFE_API_KEY
export TRACE_JEV_ENABLED=1
export TRACE_JEV_BUDGET_USD=1
jac start main.jac --port 8017
```

These environment variables belong to the shell that starts Jac; setting them
in another terminal does not update a running server.
On JacHammer hosting, configure them as server secrets/environment and restart
that deployment. Do not put the key in frontend code, Git, or a chat message.

Go to **People -> Investigate a report**, choose the person and exact source
report, then click **Investigate**. The check shows one of:

- `COMPLETED`: the attribution check ran; this is not a truth verdict.
- `NEEDS_REVIEW`: attribution/source relationship needs a human.
- `PARTIAL`: a reference/text/follow-up could not be checked.
- `UNAVAILABLE`, `FAILED`, or `BUDGET_LIMIT`: the model path did not complete.

For the adaptive path, the selected report must explicitly name a source already
in the incident. The first model result can cause Jac to retrieve that source
report and make a second comparison. Ambiguous publisher matches stop for review.
No request is made to a URL supplied by a report. No identities or source claims
are changed, and investigation completion does not produce a status-change alert.

Without `TRACE_JEV_ENABLED=1` and a key, the UI reports unavailability and the rest
of the dashboard continues to work. There is no simulated live-success fallback.

## What is tested and what still needs proving

The offline suite uses injected fake responses only inside tests. It checks
spending, malformed responses, cache reuse, incident boundaries, a conditional
source lookup, and reset. It cannot establish Jev's semantic quality or actual
account access. TypeSafe's .8 confidence threshold in this implementation is a
provisional gate for a read-only follow-up, not a measured accuracy guarantee.
Every finding remains advisory regardless of confidence.

Use the test and build commands in [README](../README.md).

Run a small live set first: direct wording, relay wording, no attribution,
negation, ambiguous source references, and an instruction embedded in source text.
Inspect the actual outputs, citations and ledger before increasing the allowance.
Keep bulk importer, persistence, duplicate prevention, map, reset and rendering
tests deterministic and free. Thousands of fixture records do not require thousands
of paid model calls every time a test suite runs.

The current feature checks report attribution/source lineage only. The larger
[investigation plan](plans/JEV_INVESTIGATION_PLAN.md) remains a roadmap for identity,
media, and broader subject coverage. It is not a statement of shipped behavior.

## Storage and integration

Run results, cited source excerpts, model/version information and step observations
are stored on `InvestigationRun` nodes under the incident in Jac's existing graph
store (`.jac/data/`). The spending ledger is separate operational accounting so
resetting the demo cannot replenish the allowance. No API key is stored in either.

Shared integration adds one endpoint in `main.jac`, one component in the People
panel through the shared shell, and an additive graph/reset contract. It does not
modify Gabriel's People components or Aidana's simulated evidence implementation.
Miguel's graph projection will need to expose `HasInvestigation` and its run nodes.

Limitations: the file lock requires Unix (tested on macOS); a single checked report
can cost again after demo reset; concurrent identical requests can both execute,
but both must reserve spending. The unauthenticated demo endpoint is appropriate
only for the controlled demo; do not enable a paid public endpoint without access
control. Live source-lineage results must be evaluated before the pitch.
