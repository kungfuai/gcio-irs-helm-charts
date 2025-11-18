# Facture Extractor

Create a minimal `values.yaml` file:

```yaml
facture:
    databaseURL: postgres://localhost:5432/facture
```

Update the helm repo and install the extractor:

```sh
$ helm repo update facture
$ helm install [release-name] facture/extractor --values values.yaml
```
