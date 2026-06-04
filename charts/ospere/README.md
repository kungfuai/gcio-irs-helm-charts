# Ospere Helm Chart

Deploys the Ospere Django service for IRS MeF filing orchestration.

The chart follows the same service pattern as the existing Facture charts:

- Django/Gunicorn web deployment
- optional Django locked migration hook job
- optional Django admin bootstrap hook job
- service account with IRSA annotations
- database and application secrets by reference
- optional ingress
- optional Celery worker and beat deployments that use the same image

Celery workloads are disabled by default until the filing lifecycle moves to asynchronous jobs.

The migration hook runs `python manage.py lockedmigrate --noinput` as a
`pre-install,pre-upgrade` hook. `lockedmigrate` comes from the `django-kubernetes`
app and uses a Postgres advisory lock so concurrent rollouts or rollbacks do not
race Django migrations.

The migration and ensure-admin hooks intentionally use the namespace default
ServiceAccount unless `jobs.*.serviceAccountName` is explicitly set. Pre-install
hooks run before normal chart resources, so referencing the chart-created Ospere
ServiceAccount would break first installs.

The ensure-admin hook is disabled by default. When enabled, it runs after locked
migrations, executes `python manage.py syncadmin`, and reads
`DJANGO_ADMIN_USERNAME`, `DJANGO_ADMIN_EMAIL`, and `DJANGO_ADMIN_PASSWORD` from
`jobs.ensureAdmin.existingSecret`. The command creates the admin user if missing
and rotates the password when the user already exists.

API authentication is controlled by `ospere.apiAuth.mode`. Supported modes are
`disabled` and `hawk`. `disabled` is intended for local/dev-only use. In deployed
environments, set `ospere.apiAuth.mode=hawk` and provide `ospere.apiAuth.hawk.secretName`.
By default, the chart reads `client_id` and `client_key` from that Secret (override via
`ospere.apiAuth.hawk.clientIdKey` / `ospere.apiAuth.hawk.clientKeyKey`). The chart renders `OSPERE_API_AUTH_MODE`, `HAWK_CLIENT_ID`, `HAWK_CLIENT_KEY`, and
`HAWK_ALGORITHM` into web, worker, beat, migrate, and ensure-admin workloads.
When mode is `hawk`, missing Hawk secret references fail chart rendering instead
of falling back to unauthenticated behavior.

MeF A2A configuration requires more than the mounted certificate. The chart exposes
the X.509 cert path, private key path, ordered `AppSysID`/ASID list
(`MEF_CLIENT_SYSTEM_IDS`), deprecated singular `AppSysID`
(`MEF_CLIENT_SYSTEM_ID`), EFIN, ETIN, tax-year SoftwareId map, default tax
year, endpoint, environment, and WSDL paths.

`ospere.mef.clientSystemIDs` is rendered as comma-separated
`MEF_CLIENT_SYSTEM_IDS`. During the compatibility period the chart can also render
`MEF_CLIENT_SYSTEM_ID`. If `ospere.mef.cert.secretName` is set, the chart can read
`MEF_CLIENT_SYSTEM_IDS`, `MEF_CLIENT_SYSTEM_ID`, `MEF_EFIN`, `MEF_ETIN`, and
`MEF_SOFTWARE_IDS_BY_TAX_YEAR` from keys in the same Kubernetes Secret that
mounts the MeF certificate bundle. This keeps
certificate and MeF account metadata on the same deployment path while the app
derives the active request AppSysID from the first ordered value.

`ospere.mef.softwareIDsByTaxYear` renders directly as JSON when set in values.
When `ospere.mef.cert.secretName` is set, the chart reads the JSON value from
`software_ids_by_tax_year`. `ospere.mef.defaultTaxYear` renders
`MEF_DEFAULT_TAX_YEAR` for MeF calls that do not carry a request tax year.

The Celery worker and beat deployments are enabled by default. The worker's
`worker.concurrency` value renders `CELERY_WORKER_CONCURRENCY`, and the default
worker args pass that value to Celery as
`--concurrency=$(CELERY_WORKER_CONCURRENCY)`. The default concurrency is `5`.
Because worker and beat are enabled by default, deployments must provide
`secrets.celeryBrokerURL.name` or `secrets.celeryBrokerURL.value`. Worker also
uses `secrets.celeryResultBackend` when result storage is configured.

Environment wiring should provide the public host through chart values. The expected
GovCIO host pattern is:

- sandbox/dev: `ospere.<dev-domain>`
- test: `ospere.<test-domain>`
- production: `ospere.<prod-domain>`

For the current Facture-style domains that means infra can set hosts such as
`ospere.facture.dev.govciocentralplatform.com`,
`ospere.facture.test.govciocentralplatform.com`, and
`ospere.facture.govciocentralplatform.com`.
