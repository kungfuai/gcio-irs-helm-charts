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
