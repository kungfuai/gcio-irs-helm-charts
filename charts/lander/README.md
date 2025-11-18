# Facture Lander

Create a minimal `values.yaml` file:

```yaml
facture:
    databaseURL: postgres://localhost:5432/facture
```

Update the helm repo and install the lander:

```sh
$ helm repo update facture
$ helm install [release-name] facture/lander --values values.yaml
```
