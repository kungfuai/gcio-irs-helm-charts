# ADR-0002: Chart Test Taxonomy and CI Contracts

**Status:** Accepted
**Date:** 2026-06-15
**Related:** [`gcio-irs-mef-service` ADR-0005 — test taxonomy and CI contracts](https://github.com/kungfuai/gcio-irs-mef-service/tree/dev/docs/adr) (the app-side analogue); [`gcio-irs-mef-service` ADR-0004 — release and deploy contract](https://github.com/kungfuai/gcio-irs-mef-service/tree/dev/docs/adr)

## Context

The app repo names its test tiers explicitly (ADR-0005: fast / contract /
integration / live) and runs the appropriate clusterless subset on every PR,
deferring the tiers that need a runtime. This repo had tiers too, but only
implicitly — the `chart-contract` workflow ran lint + render-contract +
release-version governance, and the prose "CI/CD Contract" in the README was the
only record. This ADR names the chart-side taxonomy, states what runs at PR, and
records what is intentionally deferred or owned elsewhere.

## Decision

Chart proof has four tiers. The first three are clusterless and gate every PR;
the fourth needs a runtime and is owned by infra.

| tier | what it proves | needs a cluster? | when |
|---|---|---|---|
| **lint** | each chart is structurally valid (`helm lint`) | no | PR |
| **render-contract** | `helm template` produces the exact wiring the app + infra agree on — env names, `secretKeyRef` name/key, hook weights, the cross-boundary shape | no | PR |
| **schema** | rendered manifests are valid against the Kubernetes API schema (`kubeconform -strict`) — catches malformed objects no hand-written assertion covers | no | PR |
| **install** | the chart actually installs and its `helm test` hooks pass (`ct install` into kind) | yes (ephemeral) | **deferred** — see below |
| **live** | a deployed environment has the right image, secrets, DNS, egress (smoke/canary) | yes (real) | **not here** — owned by `kfai-infra` |

Release-version validation (`validate_chart_release_versions.py`) is a governance
gate, not a test tier: it asserts a changed chart bumped `Chart.yaml` so
chart-releaser can publish on merge to `main`.

1. **The PR subset is the clusterless tiers: lint + render-contract + schema.**
   This mirrors the app running fast + contract on PR. `kubeconform` is added to
   the existing `chart-contract` job, scoped to charts that ship a
   `ci/all-values.yaml` fixture (the guaranteed-renderable ones), with
   `-ignore-missing-schemas` so CRD-based charts do not false-fail.
2. **`live` is intentionally not in this repo.** Per app ADR-0004, deployed-env
   proof (smoke, canary) belongs to `kfai-infra` for `deployment_scope=ospere`.
   This repo owns reusable chart artifacts, not environment state.
3. **`install` (the integration tier) is deferred, not rejected.** The ospere
   chart already ships `templates/tests/test-connection.yaml` as a `helm test`
   hook that nothing currently invokes. A `ct install` job into an ephemeral
   kind cluster + `helm test` is the real analogue of the app's integration
   tier. It is heavier (spins a cluster per run), so whether it gates every PR or
   runs pre-merge/nightly is left to a follow-up; this ADR records the gap so it
   is a decision, not an omission.

## Consequences

- Every PR now proves structural validity, the cross-boundary wiring shape, and
  Kubernetes-schema validity — without a cluster, so feedback stays fast.
- `kubeconform` closes the gap between "the fields we asserted" and "the manifest
  is actually valid," at near-zero cost.
- The dead `helm test` hook is acknowledged; activating it is the obvious first
  step if/when the `install` tier lands.
- The taxonomy is now recorded, so adding a tier (or moving one to nightly) is an
  explicit amendment rather than ad-hoc CI drift.

## Alternatives Considered

- **Run `kubeconform` as a pytest test that shells out, alongside the render
  contracts.** Rejected: it would add a `kubeconform` binary dependency to every
  local `pytest` run. Keeping it a CI step leaves local test runs needing only
  `helm`, and CI-oriented manifest validation is conventionally a pipeline step.
- **Validate every chart, including those without `ci/` fixtures.** Rejected:
  charts without example values (CRD/infra charts like `karpenter-nodepools`)
  are not reliably renderable without inputs; validating the fixture-backed
  charts matches what the render contracts already target.
- **Add `ct install` as a gating PR job now.** Deferred: spinning a kind cluster
  on every PR is a real cost; decide placement deliberately rather than defaulting
  it onto the critical path.
