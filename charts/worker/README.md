# Facture Worker

Create a minimal `values.yaml` file:

```yaml
facture:
    databaseURL: postgres://localhost:5432/facture
```

Update the helm repo and install the worker:

```sh
$ helm repo update facture
$ helm install [release-name] facture/worker --values values.yaml
```
