# Ospere Helm Chart

Deploys the Ospere Django service for IRS MeF filing orchestration.

The chart follows the same service pattern as the existing Facture charts:

- Django/Gunicorn web deployment
- optional Django migration hook job
- service account with IRSA annotations
- database and application secrets by reference
- optional ingress
- optional Celery worker and beat deployments that use the same image

Celery workloads are disabled by default until the filing lifecycle moves to asynchronous jobs.

The migration hook intentionally uses the namespace default ServiceAccount unless
`jobs.migrate.serviceAccountName` is explicitly set. Pre-install hooks run before
normal chart resources, so referencing the chart-created Ospere ServiceAccount
would break first installs.

MeF A2A configuration requires more than the mounted certificate. The chart exposes
the X.509 cert path, private key path, `AppSysID` (`MEF_CLIENT_SYSTEM_ID`), EFIN,
ETIN, software ID, endpoint, environment, and WSDL paths. The application must also
read any exposed env vars; at chart introduction time Ospere still needs app-side
support for `MEF_SOFTWARE_ID`.

Environment wiring should provide the public host through chart values. The expected
GovCIO host pattern is:

- sandbox/dev: `ospere.<dev-domain>`
- test: `ospere.<test-domain>`
- production: `ospere.<prod-domain>`

For the current Facture-style domains that means infra can set hosts such as
`ospere.facture.dev.govciocentralplatform.com`,
`ospere.facture.test.govciocentralplatform.com`, and
`ospere.facture.govciocentralplatform.com`.
