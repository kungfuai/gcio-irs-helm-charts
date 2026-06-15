# Architecture Decision Records

Decisions that shape the **chart-level contract** in this repo — how charts wire
env, source secrets, and stay renderable across releases — are recorded here so
they outlive any single PR.

Scope: these ADRs cover the deployment/wiring surface this repo owns. They do
**not** re-decide application behavior. App-level decisions live in the app repo
that owns the image — for Ospere that is
[`gcio-irs-mef-service/docs/adr`](https://github.com/kungfuai/gcio-irs-mef-service/tree/dev/docs/adr).
A chart ADR may reference an app ADR as the upstream authority.

| ADR | Title |
|---|---|
| [0001](0001-ospere-outbound-notification-env-wiring.md) | Ospere outbound status-notification env wiring |
| [0002](0002-chart-test-taxonomy-and-ci-contracts.md) | Chart test taxonomy and CI contracts |
