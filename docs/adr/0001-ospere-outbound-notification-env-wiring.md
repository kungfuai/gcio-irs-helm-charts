# ADR-0001: Ospere Outbound Status-Notification Env Wiring

**Status:** Accepted
**Date:** 2026-06-15
**Upstream authority:** [`gcio-irs-mef-service` ADR-0007 — status delivery, pull by default, push optional](https://github.com/kungfuai/gcio-irs-mef-service/tree/dev/docs/adr)

## Context

ADR-0007 in the app repo settles status delivery: pull (the GET endpoints) is
the contract; push (an outbound webhook) is an opt-in convenience that emits
thin, signed `Filing.status`-transition events. The app reads four env vars to
drive push: `NOTIFICATION_ENABLED`, `NOTIFICATION_URL`, `NOTIFICATION_CLIENT_ID`,
and `NOTIFICATION_CLIENT_SECRET`. The ospere chart had no outbound wiring — only
the inbound Hawk credential — so this records how the chart exposes push.

This is a chart-side wiring decision, not a re-litigation of pull-vs-push. The
app ADR remains the authority for the behavior.

## Decision

Add an `ospere.notification` values block and render the four env vars onto the
web, worker, beat, and hook workloads, mirroring the existing `ospere.apiAuth.hawk`
block.

```yaml
ospere:
  notification:
    enabled: false
    url: ""
    hmac:
      secretName: ""          # synced by infra; never chart-created
      clientIdKey: "client_id"
      clientSecretKey: "client_secret"
```

1. **Ships dark.** `enabled` defaults to `false`. `NOTIFICATION_ENABLED` is always
   rendered; `url` and the two `secretKeyRef` vars render only when enabled. A
   release promoted to any environment without setting these leaves push off,
   which matches the app default (`parse_notification_config` defaults disabled).
2. **The hmac credential is infra-synced, never chart-created.** The chart only
   references `secretName` and reads `client_id` / `client_secret` from it — the
   same lifecycle as `apiAuth.hawk`: Secrets Manager to namespace Secret via
   `kfai-infra`, then `secretKeyRef`. Per ADR-0007 the hmac credential reuses the
   existing Facture/processor-notifier secret, so this is a reference, not a new
   provisioning ask on the chart.
3. **Fail loud when enabled.** When `enabled=true`, a missing `url` or
   `hmac.secretName` fails chart rendering rather than deploying a half-wired,
   silently-broken emitter.
4. **Wire only what the app reads.** The app is hmac-only today and does not read
   `NOTIFICATION_AUTH_MODE`, so the chart does not emit it. `none` / `bearer` are
   ADR-0007 targets; they join here — as a sibling auth block plus an `authMode`
   selector — when the app gains the mode surface, in lockstep.

## Consequences

- Promoting Ospere to test/prod is safe with no notification values set: the
  feature is off. Turning it on later is values-only (set `enabled`, `url`,
  `hmac.secretName`) with no chart change, once infra has synced the credential.
- `enabled=true` without a synced Secret fails at render, not at runtime.
- There is no `BRIDGE_*` legacy to rename: the chart never shipped outbound
  wiring, so this is purely additive. (Earlier app-side docs referenced
  `BRIDGE_NOTIFICATION_*`; that name never reached this chart.)
- Chart version bumped `0.1.9 -> 0.1.10`; merging to `main` publishes it via
  chart-releaser, and the app release manifest can then pin `0.1.10`.

## Alternatives Considered

- **Source `client_id` as a plain value, only `client_secret` from the Secret.**
  Rejected: the Hawk block already co-locates id + key in one synced Secret, and
  keeping the pair together means infra provisions one object. Consistency wins.
- **Wire `NOTIFICATION_AUTH_MODE` now, defaulting `hmac`.** Rejected for now: the
  app does not read it, so it would ship a dead env var. Added when the app does.
- **Chart-managed Secret for the hmac credential.** Rejected: secrets are
  infra-synced from Secrets Manager across this platform; a chart-created Secret
  would fork that ownership and risk drift.
